import 'dart:async';

import 'package:Bloomee/blocs/library/cubit/library_items_cubit.dart';
import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/services/db/dao/library_dao.dart';
import 'package:Bloomee/services/db/dao/playlist_dao.dart';
import 'package:Bloomee/services/player/queue_manager.dart';
import 'package:Bloomee/services/share/android_share_service.dart';
import 'package:Bloomee/services/share/share_event_deduplicator.dart';
import 'package:Bloomee/services/share/shared_music_models.dart';
import 'package:Bloomee/services/shared_url_resolver_service.dart';
import 'package:Bloomee/src/rust/api/plugin/models.dart';
import 'package:Bloomee/utils/url_checker.dart';
import 'package:flutter_test/flutter_test.dart';

Track _buildTestTrack({
  required String id,
  required String title,
  required String artist,
}) {
  return Track(
    id: id,
    title: title,
    artists: [ArtistSummary(name: artist, id: 'artist_$id')],
    album: AlbumSummary(
      title: 'Test Album',
      id: 'album_$id',
      artists: [ArtistSummary(name: artist, id: 'artist_$id')],
    ),
    durationMs: BigInt.from(210000),
    thumbnail: const Artwork(url: 'https://example.com/art.jpg', layout: ImageLayout.square),
    isExplicit: false,
  );
}

class FakePlaylistDAO implements PlaylistDAO {
  final Map<String, List<Track>> _playlists = {};
  bool throwOnAdd = false;

  FakePlaylistDAO() {
    _playlists['Favorites'] = [];
    _playlists['Workout'] = [];
  }

  @override
  Future<int?> addTrackToPlaylistByName(String playlistName, Track track) async {
    if (throwOnAdd) {
      throw Exception('Database write error');
    }
    final list = _playlists.putIfAbsent(playlistName, () => []);
    if (list.any((t) => t.id == track.id)) {
      return null; // Duplicate
    }
    list.add(track);
    return list.length;
  }

  @override
  Future<int?> createPlaylist(String name,
      {dynamic thumbnail, String? description, String? subtitle}) async {
    _playlists.putIfAbsent(name, () => []);
    return _playlists.keys.toList().indexOf(name) + 1;
  }

  @override
  Future<int> ensurePlaylist(String name, {dynamic type}) async {
    _playlists.putIfAbsent(name, () => []);
    return _playlists.keys.toList().indexOf(name) + 1;
  }

  @override
  Future<List<String>> getPlaylistsContainingTrack(String mediaId) async {
    final result = <String>[];
    for (final entry in _playlists.entries) {
      if (entry.value.any((t) => t.id == mediaId)) {
        result.add(entry.key);
      }
    }
    return result;
  }

  @override
  Future<int> purgeBrokenPlaylistEntries() async => 0;

  @override
  Future<Stream<void>> watchAllPlaylists() async => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLibraryDAO implements LibraryDAO {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ShareEventDeduplicator.reset();
  });

  group('Category 1: URL Extraction from Shared Text', () {
    test('extracts standalone standard YouTube video URL', () {
      final payload = ExtractedSharePayload.fromText(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(payload.isValid, isTrue);
      expect(payload.type, SharedPayloadType.youtubeVideo);
      expect(payload.extractedUrl, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(extractVideoId(payload.extractedUrl!), 'dQw4w9WgXcQ');
    });

    test('extracts shortened youtu.be link', () {
      final payload = ExtractedSharePayload.fromText(
        'https://youtu.be/dQw4w9WgXcQ?feature=shared',
      );
      expect(payload.isValid, isTrue);
      expect(payload.type, SharedPayloadType.youtubeVideo);
      expect(extractVideoId(payload.extractedUrl!), 'dQw4w9WgXcQ');
    });

    test('extracts YouTube Shorts link', () {
      final payload = ExtractedSharePayload.fromText(
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
      );
      expect(payload.isValid, isTrue);
      expect(payload.type, SharedPayloadType.youtubeVideo);
      expect(extractVideoId(payload.extractedUrl!), 'dQw4w9WgXcQ');
    });

    test('extracts YouTube Music link', () {
      final payload = ExtractedSharePayload.fromText(
        'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(payload.isValid, isTrue);
      expect(payload.type, SharedPayloadType.youtubeVideo);
      expect(extractVideoId(payload.extractedUrl!), 'dQw4w9WgXcQ');
    });

    test('extracts YouTube URL embedded inside message text with metadata', () {
      final payload = ExtractedSharePayload.fromText(
        'Check out this song: Never Gonna Give You Up https://youtu.be/dQw4w9WgXcQ on YouTube',
      );
      expect(payload.isValid, isTrue);
      expect(payload.type, SharedPayloadType.youtubeVideo);
      expect(payload.extractedUrl, 'https://youtu.be/dQw4w9WgXcQ');
      expect(payload.metadataText, contains('Never Gonna Give You Up'));
      expect(extractVideoId(payload.extractedUrl!), 'dQw4w9WgXcQ');
    });

    test('extracts Spotify track link with accompanying title and artist', () {
      final payload = ExtractedSharePayload.fromText(
        'Never Gonna Give You Up by Rick Astley https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT?si=abc123',
      );
      expect(payload.isValid, isTrue);
      expect(payload.type, SharedPayloadType.spotifyTrack);
      expect(payload.extractedUrl, startsWith('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT'));
      expect(payload.metadataText, 'Never Gonna Give You Up by Rick Astley');
    });

    test('extracts Instagram Reel URL', () {
      final payload = ExtractedSharePayload.fromText(
        'Watch this reel by musician https://www.instagram.com/reel/C3xyz123abc/',
      );
      expect(payload.isValid, isTrue);
      expect(payload.type, SharedPayloadType.instagramReel);
      expect(payload.extractedUrl, 'https://www.instagram.com/reel/C3xyz123abc/');
      expect(payload.metadataText, 'musician');
    });

    test('strips trailing punctuation around embedded URL safely', () {
      final payload = ExtractedSharePayload.fromText(
        'Listen to this (https://youtu.be/dQw4w9WgXcQ).',
      );
      expect(payload.isValid, isTrue);
      expect(payload.extractedUrl, 'https://youtu.be/dQw4w9WgXcQ');
      expect(extractVideoId(payload.extractedUrl!), 'dQw4w9WgXcQ');
    });

    test('identifies plain text music query without URL', () {
      final payload = ExtractedSharePayload.fromText(
        'Rick Astley - Never Gonna Give You Up',
      );
      expect(payload.isValid, isTrue);
      expect(payload.type, SharedPayloadType.plainText);
      expect(payload.extractedUrl, isNull);
      expect(payload.metadataText, 'Rick Astley - Never Gonna Give You Up');
    });
  });

  group('Category 2: Invalid and Unsupported URLs', () {
    test('rejects unsafe schemes (javascript, file, content, intent)', () {
      final js = ExtractedSharePayload.fromText('javascript:alert(1)');
      expect(js.isValid, isFalse);
      expect(js.type, SharedPayloadType.invalid);

      final file = ExtractedSharePayload.fromText('file:///etc/passwd');
      expect(file.isValid, isFalse);

      final content = ExtractedSharePayload.fromText('content://media/external/images/media/1');
      expect(content.isValid, isFalse);

      final intent = ExtractedSharePayload.fromText('intent://evil.example.com#Intent;action=SEND;end');
      expect(intent.isValid, isFalse);
    });

    test('rejects excessively long input exceeding 8192 characters', () {
      final huge = 'a' * 9000;
      final payload = ExtractedSharePayload.fromText(huge);
      expect(payload.isValid, isFalse);
      expect(payload.rejectionReason, contains('maximum length'));
    });

    test('handles empty and whitespace-only shared text', () {
      final empty = ExtractedSharePayload.fromText('');
      expect(empty.isValid, isFalse);

      final whitespace = ExtractedSharePayload.fromText('   \n\t  ');
      expect(whitespace.isValid, isFalse);

      final nullPayload = ExtractedSharePayload.fromText(null);
      expect(nullPayload.isValid, isFalse);
    });

    test('identifies unsupported external non-music domains', () {
      final payload = ExtractedSharePayload.fromText(
        'https://example.com/news/article-12345',
      );
      expect(payload.isValid, isTrue);
      expect(payload.type, SharedPayloadType.otherUrl);
    });
  });

  group('Category 3: Duplicate Share-Event Handling', () {
    test('suppresses identical share events received within cooldown', () {
      const shareText = 'https://youtu.be/dQw4w9WgXcQ';
      expect(ShareEventDeduplicator.isDuplicate(shareText), isFalse);
      expect(ShareEventDeduplicator.isDuplicate(shareText), isTrue);
      expect(ShareEventDeduplicator.isDuplicate('   $shareText   '), isTrue);
    });

    test('allows distinct share events in rapid succession', () {
      expect(ShareEventDeduplicator.isDuplicate('https://youtu.be/song1'), isFalse);
      expect(ShareEventDeduplicator.isDuplicate('https://youtu.be/song2'), isFalse);
    });

    test('reset clears deduplication history', () {
      const shareText = 'https://youtu.be/dQw4w9WgXcQ';
      expect(ShareEventDeduplicator.isDuplicate(shareText), isFalse);
      ShareEventDeduplicator.reset();
      expect(ShareEventDeduplicator.isDuplicate(shareText), isFalse);
    });
  });

  group('Category 4: Successful Track Resolution and Playlist Insertion', () {
    test('resolves YouTube track and adds to existing playlist in DAO', () async {
      final fakeTrack = _buildTestTrack(
        id: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
      );

      final service = AndroidShareService(
        youtubeResolver: (url) async {
          return SharedUrlResolveResult(
            status: SharedUrlResolveStatus.success,
            track: fakeTrack,
          );
        },
      );

      final res = await service.resolveSharedContent(
        'https://youtu.be/dQw4w9WgXcQ',
      );

      expect(res.isSuccess, isTrue);
      expect(res.track?.id, 'dQw4w9WgXcQ');
      expect(res.track?.title, 'Never Gonna Give You Up');

      // Test playlist insertion
      final playlistDAO = FakePlaylistDAO();
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: FakeLibraryDAO(),
      );

      final added = await cubit.addToPlaylist(res.track!, 'Favorites', showSnackbar: false);
      expect(added, isTrue);

      final playlists = await playlistDAO.getPlaylistsContainingTrack(res.track!.id);
      expect(playlists, contains('Favorites'));
    });
  });

  group('Category 5: Resolution Failure and Manual-Search Fallback', () {
    test('Instagram Reel link produces informative explanation and manual search fallback', () async {
      const service = AndroidShareService();
      final res = await service.resolveSharedContent(
        'Watch this reel by @musician https://www.instagram.com/reel/C3xyz123/',
      );

      expect(res.status, SharedMusicResolutionStatus.needsSearchFallback);
      expect(res.track, isNull);
      expect(res.message, contains('Instagram Reel links do not provide direct song audio'));
      expect(res.suggestedQuery, isNotNull);
    });

    test('failed YouTube resolution returns fallback query with manual search message', () async {
      final service = AndroidShareService(
        youtubeResolver: (_) async =>
            const SharedUrlResolveResult(status: SharedUrlResolveStatus.failed),
      );

      final res = await service.resolveSharedContent(
        'Listen to Song Title https://youtu.be/missingId',
      );

      expect(res.status, SharedMusicResolutionStatus.needsSearchFallback);
      expect(res.suggestedQuery, contains('Song Title'));
      expect(res.message, contains('Could not automatically resolve'));
    });

    test('Spotify with accompanying metadata resolves via fast search track fallback', () async {
      final fakeTrack = _buildTestTrack(
        id: 'spot_1',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
      );

      final service = AndroidShareService(
        searchTrack: (query) async {
          if (query.contains('Blinding Lights')) return fakeTrack;
          return null;
        },
      );

      final res = await service.resolveSharedContent(
        'Blinding Lights by The Weeknd https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b',
      );

      expect(res.isSuccess, isTrue);
      expect(res.track?.title, 'Blinding Lights');
    });
  });

  group('Category 6: Existing Playlist Selection and New Playlist Creation', () {
    test('creates new playlist and persists track into it', () async {
      final playlistDAO = FakePlaylistDAO();
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: FakeLibraryDAO(),
      );

      final track = _buildTestTrack(
        id: 'new_1',
        title: 'New Track',
        artist: 'Artist',
      );

      // Create new playlist
      await cubit.createPlaylist('Roadtrip');

      // Add to the newly created playlist
      final added = await cubit.addToPlaylist(track, 'Roadtrip', showSnackbar: false);
      expect(added, isTrue);

      final containing = await playlistDAO.getPlaylistsContainingTrack(track.id);
      expect(containing, contains('Roadtrip'));
    });
  });

  group('Category 7: Persistence Failures and Duplicate Entries', () {
    test('detects duplicate entries and returns false without re-adding', () async {
      final playlistDAO = FakePlaylistDAO();
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: FakeLibraryDAO(),
      );

      final track = _buildTestTrack(
        id: 'dup_1',
        title: 'Duplicate Track',
        artist: 'Artist',
      );

      final firstAdd = await cubit.addToPlaylist(track, 'Workout', showSnackbar: false);
      expect(firstAdd, isTrue);

      // Second attempt to add same track to same playlist
      final secondAdd = await cubit.addToPlaylist(track, 'Workout', showSnackbar: false);
      expect(secondAdd, isFalse); // Duplicate suppressed!
    });

    test('rethrows persistence error on database write failure', () async {
      final playlistDAO = FakePlaylistDAO()..throwOnAdd = true;
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: FakeLibraryDAO(),
      );

      final track = _buildTestTrack(
        id: 'err_1',
        title: 'Error Track',
        artist: 'Artist',
      );

      expect(
        () => cubit.addToPlaylist(track, 'Workout', showSnackbar: false),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Category 8: Playback and Queue Preservation', () {
    test('share resolution and playlist addition leaves QueueManager completely untouched', () async {
      final queueManager = QueueManager();
      final currentTrack = _buildTestTrack(
        id: 'playing_1',
        title: 'Currently Playing',
        artist: 'Artist Active',
      );

      final initialUpcoming = [
        _buildTestTrack(id: 'up_1', title: 'Up 1', artist: 'Artist'),
        _buildTestTrack(id: 'up_2', title: 'Up 2', artist: 'Artist'),
      ];

      queueManager.loadTracks([currentTrack, ...initialUpcoming], idx: 0);

      expect(queueManager.currentTrack?.id, 'playing_1');
      expect(queueManager.tracks.length, 3);
      expect(queueManager.currentIndex, 0);

      // Execute share resolution
      final service = AndroidShareService(
        youtubeResolver: (_) async => SharedUrlResolveResult(
          status: SharedUrlResolveStatus.success,
          track: _buildTestTrack(id: 'shared_1', title: 'Shared', artist: 'Shared Artist'),
        ),
      );

      final res = await service.resolveSharedContent('https://youtu.be/shared_1');
      expect(res.isSuccess, isTrue);

      // Execute playlist addition
      final playlistDAO = FakePlaylistDAO();
      final cubit = LibraryItemsCubit(
        playlistDao: playlistDAO,
        libraryDao: FakeLibraryDAO(),
      );
      await cubit.addToPlaylist(res.track!, 'Favorites', showSnackbar: false);

      // Verify that playback queue, index, and playing track were NOT touched!
      expect(queueManager.currentTrack?.id, 'playing_1');
      expect(queueManager.tracks.length, 3);
      expect(queueManager.currentIndex, 0);
      expect(queueManager.tracks.first.id, 'playing_1');

      queueManager.dispose();
    });
  });
}
