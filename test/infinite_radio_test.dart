import 'package:flutter_test/flutter_test.dart';
import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/core/models/media_playlist_model.dart';
import 'package:Bloomee/services/db/dao/download_dao.dart';
import 'package:Bloomee/services/db/dao/history_dao.dart';
import 'package:Bloomee/services/db/dao/playlist_dao.dart';
import 'package:Bloomee/services/db/dao/settings_dao.dart';
import 'package:Bloomee/services/player/player_engine.dart';
import 'package:Bloomee/services/player/queue_manager.dart';
import 'package:Bloomee/services/player/related_songs_manager.dart';
import 'package:Bloomee/services/plugin/plugin_service.dart';
import 'package:Bloomee/services/recommendation/hybrid_recommendation_engine.dart';
import 'package:Bloomee/services/recommendation/listening_signal_collector.dart';
import 'package:Bloomee/services/recommendation/models/recommendation_models.dart';

// ── Mock DAOs for deterministic testing ──────────────────────────────────────

class FakeHistoryDAO implements HistoryDAO {
  List<Track> historyTracks = [];
  @override
  Future<List<Track>> getHistory({int limit = 50}) async =>
      historyTracks.take(limit > 0 ? limit : historyTracks.length).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePlaylistDAO implements PlaylistDAO {
  List<Track> likedTracks = [];
  @override
  Future<Playlist> loadPlaylist(String name) async {
    if (name == PlaylistDAO.likedPlaylist) {
      return Playlist(tracks: likedTracks, title: 'Liked');
    }
    return const Playlist(tracks: [], title: 'Empty');
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDownloadDAO implements DownloadDAO {
  List<Track> downloads = [];
  @override
  Future<List<Track>> getValidDownloadedTracks() async => downloads;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettingsDAO implements SettingsDAO {
  final Map<String, String> stringSettings = {};
  final Map<String, bool> boolSettings = {};

  @override
  Future<String?> getSettingStr(String key, {String? defaultValue}) async =>
      stringSettings[key] ?? defaultValue;
  @override
  Future<void> putSettingStr(String key, String value) async {
    stringSettings[key] = value;
  }
  @override
  Future<bool?> getSettingBool(String key, {bool? defaultValue}) async =>
      boolSettings[key] ?? defaultValue;
  @override
  Future<void> putSettingBool(String key, bool value) async {
    boolSettings[key] = value;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePluginService implements PluginService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockToggleEngine implements HybridRecommendationEngine {
  bool shouldThrow = false;
  List<Track> candidateTracks = [];

  @override
  Future<RadioBatchResult> getRadioTracksForSeed({
    required RadioSeed seed,
    int limit = 10,
    String? pageToken,
    Set<String> excludedTrackIds = const {},
  }) async {
    if (shouldThrow) {
      throw Exception('Simulated network failure');
    }
    return RadioBatchResult(
      tracks: candidateTracks
          .where((t) => !excludedTrackIds.contains(t.id))
          .map((t) => ScoredTrack(
                track: t,
                score: 0.9,
                reason: RecommendationReason.infiniteRadio(seed.title),
              ))
          .toList(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Track makeTestTrack({
  required String id,
  required String title,
  required String artist,
}) {
  return Track(
    id: id,
    title: title,
    artists: [ArtistSummary(name: artist, id: 'art_$artist')],
    thumbnail: const Artwork(url: '', layout: ImageLayout.square),
    isExplicit: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QueueManager removeUpcomingTracks', () {
    late QueueManager qm;

    setUp(() {
      qm = QueueManager();
    });

    tearDown(() {
      qm.dispose();
    });

    test('preserves current and past tracks when removing upcoming radio tracks', () {
      final t1 = makeTestTrack(id: 't1', title: 'Track 1', artist: 'Artist A');
      final t2 = makeTestTrack(id: 't2', title: 'Track 2', artist: 'Artist B');
      final t3 = makeTestTrack(id: 't3', title: 'Track 3 (Radio)', artist: 'Artist C');
      final t4 = makeTestTrack(id: 't4', title: 'Track 4 (Manual)', artist: 'Artist D');
      final t5 = makeTestTrack(id: 't5', title: 'Track 5 (Radio)', artist: 'Artist E');

      qm.loadTracks([t1, t2, t3, t4, t5], idx: 1); // t2 is current track
      expect(qm.currentTrack?.id, equals('t2'));

      // Radio tracks to remove: t1 (in past), t3 (upcoming), t5 (upcoming)
      qm.removeUpcomingTracks({'t1', 't3', 't5'});

      // Only t3 and t5 were upcoming and therefore removed. Past track t1 is untouched.
      expect(qm.tracks.map((t) => t.id).toList(), equals(['t1', 't2', 't4']));
      expect(qm.currentIndex, equals(1));
      expect(qm.currentTrack?.id, equals('t2'));
    });

    test('does nothing when trackIdsToRemove does not match any upcoming tracks', () {
      final t1 = makeTestTrack(id: 't1', title: 'Track 1', artist: 'Artist A');
      final t2 = makeTestTrack(id: 't2', title: 'Track 2', artist: 'Artist B');

      qm.loadTracks([t1, t2], idx: 0);
      qm.removeUpcomingTracks({'non_existent'});
      expect(qm.tracks.length, equals(2));
    });
  });

  group('HybridRecommendationEngine getRadioTracksForSeed', () {
    late FakeHistoryDAO historyDAO;
    late FakePlaylistDAO playlistDAO;
    late FakeDownloadDAO downloadDAO;
    late FakeSettingsDAO settingsDAO;
    late FakePluginService pluginService;
    late ListeningSignalCollector signalCollector;
    late HybridRecommendationEngine engine;

    setUp(() {
      historyDAO = FakeHistoryDAO();
      playlistDAO = FakePlaylistDAO();
      downloadDAO = FakeDownloadDAO();
      settingsDAO = FakeSettingsDAO();
      pluginService = FakePluginService();
      signalCollector = ListeningSignalCollector(
        settingsDao: settingsDAO,
        historyDao: historyDAO,
        playlistDao: playlistDAO,
      );
      engine = HybridRecommendationEngine(
        signalCollector: signalCollector,
        historyDao: historyDAO,
        playlistDao: playlistDAO,
        downloadDao: downloadDAO,
        settingsDao: settingsDAO,
        pluginService: pluginService,
      );
    });

    tearDown(() {
      signalCollector.dispose();
    });

    test('generates radio tracks and excludes blocked artists & disliked tracks', () async {
      final seedTrack = makeTestTrack(id: 'seed_1', title: 'Seed Song', artist: 'Seed Artist');
      final seed = RadioSeed.fromTrack(seedTrack);

      final allowedTrack = makeTestTrack(id: 'cand_1', title: 'Allowed Song', artist: 'Seed Artist');
      final dislikedTrack = makeTestTrack(id: 'disliked_1', title: 'Disliked Song', artist: 'Seed Artist');
      final blockedArtistTrack = makeTestTrack(id: 'blocked_1', title: 'Bad Song', artist: 'Blocked Artist');

      // Setup explicit dislike & blocked artist via signalCollector
      signalCollector.onTrackDisliked(dislikedTrack);
      signalCollector.onArtistDisliked('Blocked Artist');

      // Populate local sources with candidates
      playlistDAO.likedTracks = [seedTrack, allowedTrack, dislikedTrack, blockedArtistTrack];

      final batch = await engine.getRadioTracksForSeed(
        seed: seed,
        limit: 10,
        excludedTrackIds: {seedTrack.id},
      );

      final returnedIds = batch.tracks.map((t) => t.track.id).toSet();
      expect(returnedIds, contains('cand_1'));
      expect(returnedIds, isNot(contains('seed_1'))); // Excluded by seed
      expect(returnedIds, isNot(contains('disliked_1'))); // Excluded by explicit dislike
      expect(returnedIds, isNot(contains('blocked_1'))); // Excluded by blocked artist
      expect(batch.tracks.first.reason.description, contains('Infinite Radio'));
    });

    test('generates radio tracks for artist seed correctly', () async {
      const artist = ArtistSummary(name: 'A. R. Rahman', id: 'art_arr');
      final seed = RadioSeed.fromArtist(artist);

      final arrTrack1 = makeTestTrack(id: 'arr_1', title: 'Jai Ho', artist: 'A. R. Rahman');
      final arrTrack2 = makeTestTrack(id: 'arr_2', title: 'Dil Se', artist: 'A. R. Rahman');
      final otherTrack = makeTestTrack(id: 'other_1', title: 'Other Song', artist: 'Other Artist');

      playlistDAO.likedTracks = [arrTrack1, arrTrack2, otherTrack];

      final batch = await engine.getRadioTracksForSeed(
        seed: seed,
        limit: 10,
      );

      final returnedIds = batch.tracks.map((t) => t.track.id).toList();
      expect(returnedIds, contains('arr_1'));
      expect(returnedIds, contains('arr_2'));
      expect(seed.title, equals('A. R. Rahman'));
    });
  });

  group('RelatedSongsManager Infinite Radio & Queue Replenishment', () {
    late FakeHistoryDAO historyDAO;
    late FakePlaylistDAO playlistDAO;
    late FakeDownloadDAO downloadDAO;
    late FakeSettingsDAO settingsDAO;
    late FakePluginService pluginService;
    late ListeningSignalCollector signalCollector;
    late HybridRecommendationEngine engine;
    late RelatedSongsManager manager;

    setUp(() {
      historyDAO = FakeHistoryDAO();
      playlistDAO = FakePlaylistDAO();
      downloadDAO = FakeDownloadDAO();
      settingsDAO = FakeSettingsDAO();
      pluginService = FakePluginService();
      signalCollector = ListeningSignalCollector(
        settingsDao: settingsDAO,
        historyDao: historyDAO,
        playlistDao: playlistDAO,
      );
      engine = HybridRecommendationEngine(
        signalCollector: signalCollector,
        historyDao: historyDAO,
        playlistDao: playlistDAO,
        downloadDao: downloadDAO,
        settingsDao: settingsDAO,
        pluginService: pluginService,
      );
      manager = RelatedSongsManager(
        pluginService,
        recommendationEngine: engine,
      );
    });

    tearDown(() {
      manager.dispose();
      signalCollector.dispose();
    });

    test('startRadio activates radio session and generates initial tracks', () async {
      final seedTrack = makeTestTrack(id: 'seed_1', title: 'Seed Song', artist: 'Artist X');
      final cand1 = makeTestTrack(id: 'c1', title: 'Radio Song 1', artist: 'Artist X');
      final cand2 = makeTestTrack(id: 'c2', title: 'Radio Song 2', artist: 'Artist Y');
      playlistDAO.likedTracks = [seedTrack, cand1, cand2];

      final seed = RadioSeed.fromTrack(seedTrack);
      final initialTracks = await manager.startRadio(
        seed: seed,
        currentTrack: seedTrack,
      );

      expect(manager.isRadioActive.value, isTrue);
      expect(manager.activeRadioSeed.value?.title, equals('Seed Song'));
      expect(initialTracks.isNotEmpty, isTrue);
      expect(manager.isRadioTrack(initialTracks.first.id), isTrue);
      expect(manager.getReason(initialTracks.first.id)?.description, contains('Infinite Radio'));
    });

    test('replenishes queue when upcoming tracks < 3', () async {
      final seedTrack = makeTestTrack(id: 'seed_1', title: 'Seed Song', artist: 'Artist X');
      final cand1 = makeTestTrack(id: 'c1', title: 'Candidate 1', artist: 'Artist X');
      final cand2 = makeTestTrack(id: 'c2', title: 'Candidate 2', artist: 'Artist Y');
      playlistDAO.likedTracks = [cand1, cand2];

      await manager.startRadio(seed: RadioSeed.fromTrack(seedTrack));

      final queue = [
        seedTrack, // current track at index 0 -> upcoming = 0 (< 3)
      ];

      List<Track>? addedItems;
      manager.onAddQueueItems = (items, {bool atLast = false}) {
        addedItems = items;
      };

      await manager.checkForRelatedSongs(
        currentMedia: seedTrack,
        queue: queue,
        currentPlayingIdx: 0,
        loopMode: LoopMode.off,
      );

      expect(addedItems, isNotNull);
      expect(addedItems!.isNotEmpty, isTrue);
      for (final t in addedItems!) {
        expect(manager.isRadioTrack(t.id), isTrue);
      }
    });

    test('does NOT replenish when upcoming tracks >= 3', () async {
      final seedTrack = makeTestTrack(id: 'seed_1', title: 'Seed Song', artist: 'Artist X');
      final t1 = makeTestTrack(id: 't1', title: 'Track 1', artist: 'Artist A');
      final t2 = makeTestTrack(id: 't2', title: 'Track 2', artist: 'Artist B');
      final t3 = makeTestTrack(id: 't3', title: 'Track 3', artist: 'Artist C');

      await manager.startRadio(seed: RadioSeed.fromTrack(seedTrack));

      final queue = [seedTrack, t1, t2, t3]; // index 0 -> 3 upcoming

      bool wasCalled = false;
      manager.onAddQueueItems = (items, {bool atLast = false}) {
        wasCalled = true;
      };

      await manager.checkForRelatedSongs(
        currentMedia: seedTrack,
        queue: queue,
        currentPlayingIdx: 0,
        loopMode: LoopMode.off,
      );

      expect(wasCalled, isFalse);
    });

    test('does NOT replenish when LoopMode is one', () async {
      final seedTrack = makeTestTrack(id: 'seed_1', title: 'Seed Song', artist: 'Artist X');
      await manager.startRadio(seed: RadioSeed.fromTrack(seedTrack));

      bool wasCalled = false;
      manager.onAddQueueItems = (items, {bool atLast = false}) {
        wasCalled = true;
      };

      await manager.checkForRelatedSongs(
        currentMedia: seedTrack,
        queue: [seedTrack],
        currentPlayingIdx: 0,
        loopMode: LoopMode.one,
      );

      expect(wasCalled, isFalse);
    });

    test('stopRadio resets active status and prunes radio tracks when clearUpcoming is true', () async {
      final qm = QueueManager();
      final seedTrack = makeTestTrack(id: 'seed_1', title: 'Seed Song', artist: 'Artist X');
      final radioTrack = makeTestTrack(id: 'rad_1', title: 'Radio Track', artist: 'Artist X');
      final manualTrack = makeTestTrack(id: 'man_1', title: 'Manual Track', artist: 'Artist M');

      playlistDAO.likedTracks = [radioTrack];
      final seed = RadioSeed.fromTrack(seedTrack);
      await manager.startRadio(seed: seed);

      manager.markManualTrack(manualTrack.id);
      // Simulate queue: seedTrack (playing), manualTrack (manual), radioTrack (radio)
      qm.loadTracks([seedTrack, manualTrack, radioTrack], idx: 0);

      expect(manager.isRadioTrack(radioTrack.id), isTrue);
      expect(manager.isRadioTrack(manualTrack.id), isFalse);

      manager.stopRadio(clearUpcoming: true, queueManager: qm);

      expect(manager.isRadioActive.value, isFalse);
      expect(manager.activeRadioSeed.value, isNull);
      // Radio track was pruned; manual track and current track were preserved!
      expect(qm.tracks.map((t) => t.id).toList(), equals(['seed_1', 'man_1']));

      qm.dispose();
    });

    test('stale in-flight replenishment is discarded if radio is stopped while awaiting', () async {
      final seedTrack = makeTestTrack(id: 'seed_1', title: 'Seed Song', artist: 'Artist X');
      final cand1 = makeTestTrack(id: 'c1', title: 'Candidate 1', artist: 'Artist X');
      playlistDAO.likedTracks = [cand1];

      await manager.startRadio(seed: RadioSeed.fromTrack(seedTrack));

      bool itemsAdded = false;
      manager.onAddQueueItems = (items, {bool atLast = false}) {
        itemsAdded = true;
      };

      // Stop radio immediately before awaiting replenishment resolves
      final future = manager.checkForRelatedSongs(
        currentMedia: seedTrack,
        queue: [seedTrack],
        currentPlayingIdx: 0,
        loopMode: LoopMode.off,
      );
      manager.stopRadio();

      await future;
      // Stale items should NOT have been added because generation was incremented and radio was stopped
      expect(itemsAdded, isFalse);
      expect(manager.isRadioActive.value, isFalse);
    });

    test('stale in-flight startRadio is discarded if a new seed is launched concurrently', () async {
      final seed1 = RadioSeed.fromTrack(makeTestTrack(id: 's1', title: 'Seed 1', artist: 'A1'));
      final seed2 = RadioSeed.fromTrack(makeTestTrack(id: 's2', title: 'Seed 2', artist: 'A2'));

      final cand1 = makeTestTrack(id: 'c1', title: 'Cand 1', artist: 'A1');
      final cand2 = makeTestTrack(id: 'c2', title: 'Cand 2', artist: 'A2');
      playlistDAO.likedTracks = [cand1, cand2];

      final future1 = manager.startRadio(seed: seed1);
      final future2 = manager.startRadio(seed: seed2);

      final results1 = await future1;
      final results2 = await future2;

      // Seed 1 was superseded by Seed 2, so results1 should be empty
      expect(results1, isEmpty);
      expect(results2, isNotEmpty);
      expect(manager.activeRadioSeed.value?.title, equals('Seed 2'));
    });

    test('circuit breaker triggers backoff after 3 consecutive failures and recovers on success', () async {
      final mockEngine = MockToggleEngine()..shouldThrow = true;
      final failManager = RelatedSongsManager(
        pluginService,
        recommendationEngine: mockEngine,
      );

      final seedTrack = makeTestTrack(id: 'seed_1', title: 'Seed Song', artist: 'Artist X');
      await failManager.startRadio(seed: RadioSeed.fromTrack(seedTrack));

      int addCalls = 0;
      failManager.onAddQueueItems = (_, {bool atLast = false}) => addCalls++;

      // 3 consecutive failed attempts
      for (int i = 0; i < 3; i++) {
        await failManager.checkForRelatedSongs(
          currentMedia: seedTrack,
          queue: [seedTrack],
          currentPlayingIdx: 0,
          loopMode: LoopMode.off,
        );
      }

      // 4th attempt right away is blocked by the circuit breaker (within 15s)
      await failManager.checkForRelatedSongs(
        currentMedia: seedTrack,
        queue: [seedTrack],
        currentPlayingIdx: 0,
        loopMode: LoopMode.off,
      );
      expect(addCalls, equals(0));

      failManager.dispose();
    });
  });

  group('QueueManager Shuffle Mode Concurrency & Safety', () {
    late QueueManager qm;

    setUp(() {
      qm = QueueManager();
    });

    tearDown(() {
      qm.dispose();
    });

    test('removeUpcomingTracks preserves shuffle list validity when shuffle is active', () {
      final t1 = makeTestTrack(id: 't1', title: 'Track 1', artist: 'A');
      final t2 = makeTestTrack(id: 't2', title: 'Track 2', artist: 'B');
      final t3 = makeTestTrack(id: 't3', title: 'Track 3', artist: 'C');
      final t4 = makeTestTrack(id: 't4', title: 'Track 4', artist: 'D');

      qm.loadTracks([t1, t2, t3, t4], idx: 0);
      qm.shuffle(true);
      expect(qm.shuffleMode.value, isTrue);

      // Remove upcoming radio tracks t3 and t4
      qm.removeUpcomingTracks({'t3', 't4'});

      expect(qm.tracks.length, equals(2));
      // Shuffle indices must not exceed new queue length
      expect(qm.tracks.map((t) => t.id).toList(), equals(['t1', 't2']));
    });

    test('removeUpcomingTracks is a no-op when index is at the last track', () {
      final t1 = makeTestTrack(id: 't1', title: 'Track 1', artist: 'A');
      final t2 = makeTestTrack(id: 't2', title: 'Track 2', artist: 'B');

      qm.loadTracks([t1, t2], idx: 1); // Last track is current
      qm.removeUpcomingTracks({'t1', 't2'});

      expect(qm.tracks.length, equals(2));
      expect(qm.currentIndex, equals(1));
    });
  });
}
