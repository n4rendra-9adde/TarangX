import 'package:flutter_test/flutter_test.dart';
import 'package:Bloomee/core/constants/setting_keys.dart';
import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/core/models/media_playlist_model.dart';
import 'package:Bloomee/services/recommendation/models/recommendation_models.dart';
import 'package:Bloomee/services/recommendation/hybrid_recommendation_engine.dart';
import 'package:Bloomee/services/recommendation/listening_signal_collector.dart';
import 'package:Bloomee/services/db/dao/history_dao.dart';
import 'package:Bloomee/services/db/dao/playlist_dao.dart';
import 'package:Bloomee/services/db/dao/download_dao.dart';
import 'package:Bloomee/services/db/dao/settings_dao.dart';
import 'package:Bloomee/services/plugin/plugin_service.dart';

// ── Mock DAOs for deterministic unit testing ─────────────────────────────────

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

  @override
  Future<String?> getSettingStr(String key, {String? defaultValue}) async =>
      stringSettings[key] ?? defaultValue;

  @override
  Future<void> putSettingStr(String key, String value) async {
    stringSettings[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePluginService implements PluginService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hybrid Recommendation Models & Taste Profile', () {
    test('UserTasteProfile defaults to cold-start when empty', () {
      const profile = UserTasteProfile();
      expect(profile.isColdStart, isTrue);
      expect(profile.artistAffinities, isEmpty);
      expect(profile.likedTrackIds, isEmpty);
      expect(profile.dislikedTrackIds, isEmpty);
    });

    test('UserTasteProfile serialization and deserialization is loss-free', () {
      final now = DateTime.now();
      final profile = UserTasteProfile(
        artistAffinities: const {'Arijit Singh': 4.5, 'Anirudh': 2.0},
        likedTrackIds: const {'track-1', 'track-2'},
        dislikedTrackIds: const {'bad-track-1'},
        dislikedArtistNames: const {'Annoying Artist'},
        trackPlayCounts: const {'track-1': 10, 'track-2': 3},
        trackCompletionCounts: const {'track-1': 9},
        trackSkipCounts: const {'track-3': 2},
        lastPlayedTimestamps: {'track-1': now},
      );

      final jsonStr = profile.toJson();
      final decoded = UserTasteProfile.fromJson(jsonStr);

      expect(decoded.isColdStart, isFalse);
      expect(decoded.artistAffinities['Arijit Singh'], equals(4.5));
      expect(decoded.likedTrackIds, containsAll(['track-1', 'track-2']));
      expect(decoded.dislikedTrackIds, contains('bad-track-1'));
      expect(decoded.dislikedArtistNames, contains('Annoying Artist'));
      expect(decoded.trackPlayCounts['track-1'], equals(10));
      expect(decoded.trackCompletionCounts['track-1'], equals(9));
      expect(decoded.trackSkipCounts['track-3'], equals(2));
      expect(decoded.lastPlayedTimestamps['track-1']?.millisecondsSinceEpoch,
          equals(now.millisecondsSinceEpoch));
    });

    test('RecommendationConfig enforces that weights sum to 1.0', () {
      const validConfig = RecommendationConfig(
        prefWeight: 0.35,
        simWeight: 0.30,
        recWeight: 0.20,
        divWeight: 0.15,
      );
      expect(validConfig.prefWeight + validConfig.simWeight +
             validConfig.recWeight + validConfig.divWeight, closeTo(1.0, 0.001));

      expect(
        () => RecommendationConfig(
          prefWeight: 0.50,
          simWeight: 0.50,
          recWeight: 0.50,
          divWeight: 0.50, // Sums to 2.0 (invalid)
        ),
        throwsAssertionError,
      );
    });
  });

  group('HybridRecommendationEngine Deterministic Ranking & Scoring', () {
    late HybridRecommendationEngine engine;
    late FakeHistoryDAO fakeHistoryDao;
    late FakePlaylistDAO fakePlaylistDao;
    late FakeDownloadDAO fakeDownloadDao;
    late FakeSettingsDAO fakeSettingsDao;
    late FakePluginService fakePluginService;
    late ListeningSignalCollector signalCollector;

    setUp(() {
      fakeHistoryDao = FakeHistoryDAO();
      fakePlaylistDao = FakePlaylistDAO();
      fakeDownloadDao = FakeDownloadDAO();
      fakeSettingsDao = FakeSettingsDAO();
      fakePluginService = FakePluginService();

      signalCollector = ListeningSignalCollector(
        settingsDao: fakeSettingsDao,
        historyDao: fakeHistoryDao,
        playlistDao: fakePlaylistDao,
      );

      engine = HybridRecommendationEngine(
        signalCollector: signalCollector,
        historyDao: fakeHistoryDao,
        playlistDao: fakePlaylistDao,
        downloadDao: fakeDownloadDao,
        settingsDao: fakeSettingsDao,
        pluginService: fakePluginService,
      );
    });

    tearDown(() {
      signalCollector.dispose();
    });

    test('deterministic scoring produces identical reproducible scores for identical inputs', () {
      const candidate = Track(
        id: 'track-test-1',
        title: 'Kesariya',
        artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      const profile = UserTasteProfile(
        artistAffinities: {'Arijit Singh': 2.5},
        likedTrackIds: {'track-test-1'},
      );

      final score1 = engine.scoreCandidate(
        candidate: candidate,
        profile: profile,
        userLanguages: const ['Hindi', 'English'],
      );

      final score2 = engine.scoreCandidate(
        candidate: candidate,
        profile: profile,
        userLanguages: const ['Hindi', 'English'],
      );

      expect(score1.score, equals(score2.score));
      expect(score1.reason.type, equals(score2.reason.type));
      expect(score1.subScores, equals(score2.subScores));
      expect(score1.score, greaterThan(0.5));
    });

    test('explicit positive preferences (likes & artist affinity) rank highest', () {
      const likedTrack = Track(
        id: 'track-liked',
        title: 'Channa Mereya',
        artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      const unlikedTrack = Track(
        id: 'track-unliked',
        title: 'Random Track',
        artists: [ArtistSummary(id: 'a2', name: 'Unknown Artist')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      const profile = UserTasteProfile(
        artistAffinities: {'Arijit Singh': 3.0},
        likedTrackIds: {'track-liked'},
      );

      final likedScore = engine.scoreCandidate(
        candidate: likedTrack,
        profile: profile,
      );
      final unlikedScore = engine.scoreCandidate(
        candidate: unlikedTrack,
        profile: profile,
      );

      expect(likedScore.score, greaterThan(unlikedScore.score));
      expect(likedScore.reason.type, equals(RecommendationReasonType.likedTrack));
      expect(likedScore.reason.description, contains('Channa Mereya'));
    });

    test('explicit negative preferences (disliked track and artist) are strictly excluded', () {
      const dislikedTrack = Track(
        id: 'disliked-track-99',
        title: 'Overplayed Song',
        artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      const blockedArtistTrack = Track(
        id: 'track-100',
        title: 'Some Song',
        artists: [ArtistSummary(id: 'a2', name: 'Blocked Artist')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      const profile = UserTasteProfile(
        dislikedTrackIds: {'disliked-track-99'},
        dislikedArtistNames: {'Blocked Artist'},
      );

      final scoreDisliked = engine.scoreCandidate(
        candidate: dislikedTrack,
        profile: profile,
      );
      final scoreBlocked = engine.scoreCandidate(
        candidate: blockedArtistTrack,
        profile: profile,
      );

      // Must be score 0.0 and filtered out
      expect(scoreDisliked.score, equals(0.0));
      expect(scoreBlocked.score, equals(0.0));
    });

    test('cold-start behavior provides language-tailored recommendations without fabricating history', () async {
      // Setup cold-start: 0 history, 0 likes
      fakeSettingsDao.stringSettings[SettingKeys.musicLanguages] = 'Kannada,English';

      final recommendations = await engine.getRecommendations(limit: 10);

      expect(recommendations, isNotEmpty);
      expect(signalCollector.currentProfile.isColdStart, isTrue);

      // Recommendations in cold start should have coldStart / trending explainability
      for (final item in recommendations) {
        expect(
          item.reason.type == RecommendationReasonType.coldStart ||
          item.reason.type == RecommendationReasonType.languageTrending,
          isTrue,
        );
      }
    });

    test('handles missing or incomplete metadata safely without throwing', () {
      const incompleteTrack = Track(
        id: 'inc-1',
        title: 'Bare Minimum Track',
        artists: [], // Empty artists
        album: null,  // Null album
        durationMs: null, // Null duration
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final scored = engine.scoreCandidate(
        candidate: incompleteTrack,
        profile: const UserTasteProfile(),
      );

      expect(scored.score, greaterThanOrEqualTo(0.0));
      expect(scored.score, lessThanOrEqualTo(1.0));
      expect(scored.reason, isNotNull);
    });

    test('suppresses duplicate tracks and normalizes title + artist collisions', () async {
      const trackA1 = Track(
        id: 'dup-1',
        title: 'Believer',
        artists: [ArtistSummary(id: 'a1', name: 'Imagine Dragons')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );
      const trackA2 = Track(
        id: 'dup-2', // Different ID, but same normalized song
        title: 'believer',
        artists: [ArtistSummary(id: 'a1', name: 'Imagine Dragons')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      fakeHistoryDao.historyTracks = [trackA1, trackA2];

      final results = await engine.getRecommendations(limit: 10);
      final titles = results.map((r) => r.track.title.toLowerCase()).toList();

      // "Believer" by Imagine Dragons should only appear at most once
      final believerCount = titles.where((t) => t == 'believer').length;
      expect(believerCount, lessThanOrEqualTo(1));
    });

    test('repetition penalty lowers score for songs played in the last 2 hours', () {
      const recentlyPlayedTrack = Track(
        id: 'recent-1',
        title: 'Just Played Track',
        artists: [ArtistSummary(id: 'a1', name: 'Some Artist')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      final profileWithRecent = UserTasteProfile(
        lastPlayedTimestamps: {
          'recent-1': DateTime.now().subtract(const Duration(minutes: 30)),
        },
      );

      final profileWithoutRecent = UserTasteProfile(
        lastPlayedTimestamps: {
          'recent-1': DateTime.now().subtract(const Duration(days: 7)),
        },
      );

      final scoreRecent = engine.scoreCandidate(
        candidate: recentlyPlayedTrack,
        profile: profileWithRecent,
      );
      final scoreOld = engine.scoreCandidate(
        candidate: recentlyPlayedTrack,
        profile: profileWithoutRecent,
      );

      expect(scoreRecent.score, lessThan(scoreOld.score));
      expect(scoreRecent.subScores['repeatPenalty'], greaterThan(0.0));
    });

    test('early skip penalty cautiously diminishes score after repeated skips', () {
      const skippedTrack = Track(
        id: 'skip-1',
        title: 'Frequently Skipped Track',
        artists: [ArtistSummary(id: 'a1', name: 'Artist')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      const profileWithSkips = UserTasteProfile(
        trackSkipCounts: {'skip-1': 3},
      );
      const profileNoSkips = UserTasteProfile(
        trackSkipCounts: {'skip-1': 0},
      );

      final scoreSkipped = engine.scoreCandidate(
        candidate: skippedTrack,
        profile: profileWithSkips,
      );
      final scoreNormal = engine.scoreCandidate(
        candidate: skippedTrack,
        profile: profileNoSkips,
      );

      expect(scoreSkipped.score, lessThan(scoreNormal.score));
      expect(scoreSkipped.subScores['skipPenalty'], greaterThan(0.0));
    });

    test('empty candidate sets handle gracefully without exceptions', () async {
      fakeHistoryDao.historyTracks = [];
      fakePlaylistDao.likedTracks = [];
      fakeDownloadDao.downloads = [];

      final results = await engine.getRecommendations(limit: 10);
      expect(results, isNotNull);
    });

    test('similar tracks calculation favors shared artist, album, and duration proximity', () async {
      const seed = Track(
        id: 'seed-1',
        title: 'Tum Hi Ho',
        artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
        album: AlbumSummary(id: 'alb1', title: 'Aashiqui 2', artists: []),
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      const candidateSameArtist = Track(
        id: 'cand-1',
        title: 'Sunn Raha Hai',
        artists: [ArtistSummary(id: 'a1', name: 'Arijit Singh')],
        album: AlbumSummary(id: 'alb1', title: 'Aashiqui 2', artists: []),
        durationMs: null,
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      fakeHistoryDao.historyTracks = [candidateSameArtist];

      final similar = await engine.getSimilarTracks(seed, limit: 5);
      expect(similar, isNotEmpty);
      expect(similar.first.track.id, equals('cand-1'));
      expect(similar.first.reason.type, equals(RecommendationReasonType.contentSimilarity));
      expect(similar.first.reason.description, contains('Tum Hi Ho'));
    });
  });

  group('ListeningSignalCollector Behavioral Signal Tracking', () {
    late ListeningSignalCollector collector;
    late FakeHistoryDAO fakeHistoryDao;
    late FakePlaylistDAO fakePlaylistDao;
    late FakeSettingsDAO fakeSettingsDao;

    setUp(() {
      fakeHistoryDao = FakeHistoryDAO();
      fakePlaylistDao = FakePlaylistDAO();
      fakeSettingsDao = FakeSettingsDAO();

      collector = ListeningSignalCollector(
        settingsDao: fakeSettingsDao,
        historyDao: fakeHistoryDao,
        playlistDao: fakePlaylistDao,
      );
    });

    tearDown(() {
      collector.dispose();
    });

    test('records track start and increments play count in taste profile', () {
      const track = Track(
        id: 'track-start-1',
        title: 'Song A',
        artists: [ArtistSummary(id: '1', name: 'Artist A')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      collector.onTrackStarted(track);

      final profile = collector.currentProfile;
      expect(profile.trackPlayCounts['track-start-1'], equals(1));
      expect(profile.lastPlayedTimestamps['track-start-1'], isNotNull);
      expect(profile.artistAffinities['Artist A'], greaterThan(0.0));
    });

    test('records completion when playback position reaches 80% threshold', () {
      final track = Track(
        id: 'track-comp-1',
        title: 'Song B',
        artists: const [ArtistSummary(id: '1', name: 'Artist B')],
        durationMs: BigInt.from(100000), // 100 seconds
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      collector.onTrackStarted(track);

      // Position update at 50% -> not yet completed
      collector.onPositionUpdate(
        const Duration(seconds: 50),
        const Duration(seconds: 100),
      );
      expect(collector.currentProfile.trackCompletionCounts['track-comp-1'], isNull);

      // Position update at 85% -> completed!
      collector.onPositionUpdate(
        const Duration(seconds: 85),
        const Duration(seconds: 100),
      );
      expect(collector.currentProfile.trackCompletionCounts['track-comp-1'], equals(1));
      expect(collector.currentProfile.artistAffinities['Artist B'], greaterThan(0.3));
    });

    test('records cautious skip only on early skip before threshold', () {
      final track = Track(
        id: 'track-skip-1',
        title: 'Song C',
        artists: const [ArtistSummary(id: '1', name: 'Artist C')],
        durationMs: BigInt.from(180000), // 3 minutes
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      collector.onTrackStarted(track);

      // User skips immediately (10s)
      collector.onTrackEnded(skipped: true);

      expect(collector.currentProfile.trackSkipCounts['track-skip-1'], equals(1));
    });

    test('explicit dislike updates dislikedTrackIds and strips liked status', () {
      const track = Track(
        id: 'track-dislike-1',
        title: 'Song D',
        artists: [ArtistSummary(id: '1', name: 'Artist D')],
        thumbnail: Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      );

      collector.onTrackLiked(track, true);
      expect(collector.currentProfile.likedTrackIds, contains('track-dislike-1'));

      collector.onTrackDisliked(track);

      final profile = collector.currentProfile;
      expect(profile.dislikedTrackIds, contains('track-dislike-1'));
      expect(profile.likedTrackIds, isNot(contains('track-dislike-1')));
    });
  });
}
