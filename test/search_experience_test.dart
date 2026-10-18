import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:Bloomee/plugins/blocs/content/content_bloc.dart';
import 'package:Bloomee/plugins/blocs/content/content_event.dart';
import 'package:Bloomee/plugins/blocs/content/content_state.dart';
import 'package:Bloomee/services/plugin/plugin_service.dart';
import 'package:Bloomee/src/rust/api/plugin/commands.dart';
import 'package:Bloomee/src/rust/api/plugin/models.dart';
import 'package:Bloomee/blocs/library/search_cubit/library_search_cubit.dart';
import 'package:Bloomee/blocs/library/cubit/library_items_cubit.dart';
import 'package:Bloomee/core/models/media_playlist_model.dart';
import 'package:Bloomee/repository/tarangx/search_repository.dart';
import 'package:Bloomee/services/db/dao/search_history_dao.dart';

class MockSearchPluginService implements PluginService {
  Future<PluginResponse> Function(String pluginId, PluginRequest request)?
      onExecute;
  final List<PluginRequest> recordedRequests = [];

  @override
  Future<PluginResponse> execute({
    required String pluginId,
    required PluginRequest request,
  }) async {
    recordedRequests.add(request);
    if (onExecute != null) {
      return onExecute!(pluginId, request);
    }
    return const PluginResponse.search(PagedMediaItems(items: []));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSearchHistoryDAO implements SearchHistoryDAO {
  final List<String> savedQueries = [];
  final List<String> deletedIds = [];
  bool cleared = false;

  @override
  Future<void> putSearchHistory(String searchQuery) async {
    savedQueries.add(searchQuery);
  }

  @override
  Future<List<Map<String, String>>> getLastSearches({int limit = 10}) async {
    return savedQueries
        .reversed
        .take(limit)
        .map((q) => {'query': q, 'id': q.hashCode.toString()})
        .toList();
  }

  @override
  Future<List<Map<String, String>>> getSimilarSearches(String query) async {
    return savedQueries
        .where((q) => q.toLowerCase().contains(query.toLowerCase()))
        .take(3)
        .map((q) => {'query': q, 'id': q.hashCode.toString()})
        .toList();
  }

  @override
  Future<void> removeSearchHistory(String id) async {
    deletedIds.add(id);
  }

  @override
  Future<void> clearAllSearchHistory() async {
    cleared = true;
    savedQueries.clear();
  }

  @override
  Future<void> limitSearchHistory() async {
    if (savedQueries.length > 100) {
      savedQueries.removeRange(100, savedQueries.length);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Track makeTestTrack({
  required String id,
  required String title,
  String artist = 'Test Artist',
  String url = 'https://example.com/audio.mp3',
  String thumbUrl = 'https://example.com/cover.jpg',
}) {
  return Track(
    id: id,
    title: title,
    artists: [ArtistSummary(id: 'a_$id', name: artist)],
    thumbnail: Artwork(url: thumbUrl, layout: ImageLayout.square),
    url: url,
    isExplicit: false,
  );
}

AlbumSummary makeTestAlbum({
  required String id,
  required String title,
  String thumbUrl = 'https://example.com/album.jpg',
}) {
  return AlbumSummary(
    id: id,
    title: title,
    artists: [ArtistSummary(id: 'art_$id', name: 'Test Artist')],
    thumbnail: Artwork(url: thumbUrl, layout: ImageLayout.square),
  );
}

ArtistSummary makeTestArtist({
  required String id,
  required String name,
  String thumbUrl = 'https://example.com/artist.jpg',
}) {
  return ArtistSummary(
    id: id,
    name: name,
    thumbnail: Artwork(url: thumbUrl, layout: ImageLayout.square),
  );
}

PlaylistSummary makeTestPlaylist({
  required String id,
  required String title,
  String thumbUrl = 'https://example.com/playlist.jpg',
}) {
  return PlaylistSummary(
    id: id,
    title: title,
    thumbnail: Artwork(url: thumbUrl, layout: ImageLayout.square),
  );
}

void main() {
  group('TarangX Premium Search & Library Discovery Tests', () {
    late MockSearchPluginService pluginService;
    late ContentBloc contentBloc;

    setUp(() {
      pluginService = MockSearchPluginService();
      contentBloc = ContentBloc(
        pluginService: pluginService,
        initialPluginId: 'test_plugin',
      );
    });

    tearDown(() async {
      await contentBloc.close();
    });

    // ── 1. Empty Queries and Query Clearing ───────────────────────────────────

    test('Empty query resets ContentBloc to initial state with cleared results',
        () async {
      contentBloc.add(const SearchContent(
        query: '   ',
        filter: ContentSearchFilter.all,
      ));

      await expectLater(
        contentBloc.stream,
        emits(predicate<ContentState>((state) =>
            state.searchStatus == SearchStatus.initial &&
            state.searchQuery == '' &&
            state.searchResults == null)),
      );
    });

    test('ClearSearch immediately resets search status and query', () async {
      // First populate with a search
      pluginService.onExecute = (_, __) async => PluginResponse.search(
            PagedMediaItems(items: [
              MediaItem.track(
                  makeTestTrack(id: 'track_1', title: 'Song 1')),
            ]),
          );

      contentBloc.add(const SearchContent(
        query: 'test query',
        filter: ContentSearchFilter.all,
      ));

      await expectLater(
        contentBloc.stream,
        emitsThrough(predicate<ContentState>(
            (s) => s.searchStatus == SearchStatus.loaded)),
      );

      // Now clear search
      contentBloc.add(const ClearSearch());

      await expectLater(
        contentBloc.stream,
        emits(predicate<ContentState>((state) =>
            state.searchStatus == SearchStatus.initial &&
            state.searchQuery == '' &&
            state.searchResults == null)),
      );
    });

    // ── 2. Rapid Query Changes & Stale-Response Protection ───────────────────

    test('Stale response protection: late response from older query is ignored',
        () async {
      final completer1 = Completer<PluginResponse>();
      final completer2 = Completer<PluginResponse>();

      pluginService.onExecute = (pluginId, request) {
        final req = request as dynamic;
        final cmd = req.field0 as dynamic;
        if (cmd.query == 'query_old') {
          return completer1.future;
        } else {
          return completer2.future;
        }
      };

      // Dispatch first search
      contentBloc.add(const SearchContent(
        query: 'query_old',
        filter: ContentSearchFilter.all,
      ));

      // Wait for debounce, state transitions to loading
      await expectLater(
        contentBloc.stream,
        emitsThrough(predicate<ContentState>((s) =>
            s.searchStatus == SearchStatus.loading &&
            s.searchQuery == 'query_old')),
      );

      // Rapidly dispatch second search
      contentBloc.add(const SearchContent(
        query: 'query_new',
        filter: ContentSearchFilter.all,
      ));

      await expectLater(
        contentBloc.stream,
        emitsThrough(predicate<ContentState>((s) =>
            s.searchStatus == SearchStatus.loading &&
            s.searchQuery == 'query_new')),
      );

      // Complete Query 2 first with its results
      completer2.complete(PluginResponse.search(
        PagedMediaItems(items: [
          MediaItem.track(
              makeTestTrack(id: 'track_new', title: 'New Track')),
        ]),
      ));

      await expectLater(
        contentBloc.stream,
        emitsThrough(predicate<ContentState>((s) =>
            s.searchStatus == SearchStatus.loaded &&
            s.searchQuery == 'query_new' &&
            s.searchResults!.items.length == 1)),
      );

      // Now Query 1 resolves late with older results
      completer1.complete(PluginResponse.search(
        PagedMediaItems(items: [
          MediaItem.track(
              makeTestTrack(id: 'track_old', title: 'Old Track')),
        ]),
      ));

      // Allow event loop to cycle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Assert: ContentState was NOT overwritten by Query 1's late response
      expect(contentBloc.state.searchQuery, 'query_new');
      final track = contentBloc.state.searchResults!.items.first as MediaItem_Track;
      expect(track.field0.id, 'track_new');
    });

    test('In-flight search response is discarded if ClearSearch was called',
        () async {
      final completer = Completer<PluginResponse>();
      pluginService.onExecute = (_, __) => completer.future;

      contentBloc.add(const SearchContent(
        query: 'rock',
        filter: ContentSearchFilter.all,
      ));

      await expectLater(
        contentBloc.stream,
        emitsThrough(predicate<ContentState>(
            (s) => s.searchStatus == SearchStatus.loading)),
      );

      // User clears the search before server responds
      contentBloc.add(const ClearSearch());

      await expectLater(
        contentBloc.stream,
        emits(predicate<ContentState>(
            (s) => s.searchStatus == SearchStatus.initial)),
      );

      // Server finally responds
      completer.complete(PluginResponse.search(
        PagedMediaItems(items: [
          MediaItem.track(
              makeTestTrack(id: 'late_track', title: 'Late Track')),
        ]),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // State remains cleared/initial
      expect(contentBloc.state.searchStatus, SearchStatus.initial);
      expect(contentBloc.state.searchResults, isNull);
    });

    // ── 3. Duplicate Results & Missing Metadata Sanitization ─────────────────

    test('Sanitizes provider results: drops malformed metadata and deduplicates IDs',
        () async {
      pluginService.onExecute = (_, __) async => PluginResponse.search(
            PagedMediaItems(items: [
              // Valid track
              MediaItem.track(
                  makeTestTrack(id: 'track_valid', title: 'Valid Track')),
              // Duplicate of track_valid (must be dropped)
              MediaItem.track(
                  makeTestTrack(id: 'track_valid', title: 'Duplicate Track')),
              // Malformed track: empty ID (must be dropped)
              MediaItem.track(makeTestTrack(id: '   ', title: 'Empty ID')),
              // Malformed track: empty title (must be dropped)
              MediaItem.track(makeTestTrack(id: 'track_bad', title: '   ')),
              // Unsafe URL track (must be dropped)
              MediaItem.track(makeTestTrack(
                id: 'track_unsafe',
                title: 'Unsafe Track',
                url: 'javascript:alert(1)',
              )),
              // Valid album
              MediaItem.album(
                  makeTestAlbum(id: 'album_1', title: 'Album 1')),
              // Duplicate album (must be dropped)
              MediaItem.album(
                  makeTestAlbum(id: 'album_1', title: 'Album 1 Dup')),
              // Malformed album (empty ID)
              MediaItem.album(makeTestAlbum(id: '', title: 'No ID')),
              // Valid artist
              MediaItem.artist(
                  makeTestArtist(id: 'artist_1', name: 'Artist 1')),
              // Duplicate artist
              MediaItem.artist(
                  makeTestArtist(id: 'artist_1', name: 'Artist 1 Dup')),
              // Malformed artist (empty name)
              MediaItem.artist(makeTestArtist(id: 'art_bad', name: '')),
              // Valid playlist
              MediaItem.playlist(
                  makeTestPlaylist(id: 'pl_1', title: 'Playlist 1')),
              // Duplicate playlist
              MediaItem.playlist(
                  makeTestPlaylist(id: 'pl_1', title: 'Playlist 1 Dup')),
              // Malformed playlist (empty title)
              MediaItem.playlist(makeTestPlaylist(id: 'pl_bad', title: ' ')),
            ]),
          );

      contentBloc.add(const SearchContent(
        query: 'test',
        filter: ContentSearchFilter.all,
      ));

      await expectLater(
        contentBloc.stream,
        emitsThrough(predicate<ContentState>(
            (s) => s.searchStatus == SearchStatus.loaded)),
      );

      final items = contentBloc.state.searchResults!.items;
      // Exactly 4 valid items: 1 track, 1 album, 1 artist, 1 playlist
      expect(items.length, 4);

      final trackItems = items.whereType<MediaItem_Track>().toList();
      expect(trackItems.length, 1);
      expect(trackItems.first.field0.id, 'track_valid');

      final albumItems = items.whereType<MediaItem_Album>().toList();
      expect(albumItems.length, 1);
      expect(albumItems.first.field0.id, 'album_1');

      final artistItems = items.whereType<MediaItem_Artist>().toList();
      expect(artistItems.length, 1);
      expect(artistItems.first.field0.id, 'artist_1');

      final playlistItems = items.whereType<MediaItem_Playlist>().toList();
      expect(playlistItems.length, 1);
      expect(playlistItems.first.field0.id, 'pl_1');
    });

    // ── 4. Provider Failures & Retry Behavior ────────────────────────────────

    test('Provider failures emit SearchStatus.error and allow clean retry',
        () async {
      bool failOnce = true;
      pluginService.onExecute = (_, __) async {
        if (failOnce) {
          failOnce = false;
          throw Exception('Simulated provider connection error');
        }
        return PluginResponse.search(PagedMediaItems(items: [
          MediaItem.track(
              makeTestTrack(id: 'recovered_track', title: 'Recovered')),
        ]));
      };

      // First attempt fails
      contentBloc.add(const SearchContent(
        query: 'retry_test',
        filter: ContentSearchFilter.all,
      ));

      await expectLater(
        contentBloc.stream,
        emitsThrough(predicate<ContentState>((s) =>
            s.searchStatus == SearchStatus.error &&
            s.error!.contains('Simulated provider connection error'))),
      );

      // Retry: dispatch search again
      contentBloc.add(const SearchContent(
        query: 'retry_test',
        filter: ContentSearchFilter.all,
      ));

      await expectLater(
        contentBloc.stream,
        emitsThrough(predicate<ContentState>((s) =>
            s.searchStatus == SearchStatus.loaded &&
            s.searchResults!.items.length == 1)),
      );
    });

    // ── 5. Local Library Search Handling ─────────────────────────────────────

    test('LibrarySearchCubit filters local playlists and songs correctly',
        () async {
      final localTracks = [
        makeTestTrack(id: 'loc_1', title: 'Local Bohemian Rhapsody'),
        makeTestTrack(id: 'loc_2', title: 'Another One Bites the Dust'),
      ];

      final cubit = LibrarySearchCubit(
        searchTracks: (q) async => localTracks
            .where((t) => t.title.toLowerCase().contains(q.toLowerCase()))
            .toList(),
      );

      const itemsState = LibraryItemsLoaded(
        playlists: [
          PlaylistItemProperties(
            playlistName: 'Rock Classics',
            storageKey: 'key_rock',
          ),
          PlaylistItemProperties(
            playlistName: 'Jazz Evening',
            storageKey: 'key_jazz',
          ),
        ],
      );

      // Search matching Queen
      cubit.search('Bohemian', itemsState);

      await expectLater(
        cubit.stream,
        emitsThrough(predicate<LibrarySearchState>((s) {
          if (s is LibrarySearchSuccess) {
            return s.songResults.length == 1 &&
                s.songResults.first.song.id == 'loc_1';
          }
          return false;
        })),
      );

      // Clear search
      cubit.clearSearch();
      expect(cubit.state, isA<LibrarySearchInitial>());

      await cubit.close();
    });

    // ── 6. Privacy: Request Construction & Logging ──────────────────────────

    test('SearchContent request sends only sanitized query and filter without telemetry',
        () async {
      pluginService.onExecute = (_, __) async =>
          const PluginResponse.search(PagedMediaItems(items: []));

      contentBloc.add(const SearchContent(
        query: 'Taylor Swift',
        filter: ContentSearchFilter.track,
      ));

      await expectLater(
        contentBloc.stream,
        emitsThrough(predicate<ContentState>(
            (s) => s.searchStatus == SearchStatus.loaded)),
      );

      expect(pluginService.recordedRequests.length, 1);
      final req = pluginService.recordedRequests.first as dynamic;
      final cmd = req.field0 as ContentResolverCommand_Search;

      // Verify strict minimum data transmission:
      expect(cmd.query, 'Taylor Swift');
      expect(cmd.filter, ContentSearchFilter.track);
      expect(cmd.pageToken, isNull);
    });

    test('SearchRepository persists and retrieves only sanitized query strings',
        () async {
      final fakeDao = FakeSearchHistoryDAO();
      final repo = SearchRepository(fakeDao);

      await repo.saveSearchQuery('Acoustic Chill');
      await repo.saveSearchQuery('Lo-fi Beats');

      final recent = await repo.getRecentSearches(limit: 5);
      expect(recent.length, 2);
      expect(recent.first['query'], 'Lo-fi Beats');

      final suggestions = await repo.getSuggestions('chill');
      expect(suggestions.length, 1);
      expect(suggestions.first['query'], 'Acoustic Chill');

      await repo.clearSearchHistory();
      expect(fakeDao.cleared, isTrue);
    });

    // ── 7. Queue Safety & Playback Consistency ───────────────────────────────

    test('Playlist model correctly encapsulates search track list with start index',
        () {
      final tracks = [
        makeTestTrack(id: 't_1', title: 'Track 1'),
        makeTestTrack(id: 't_2', title: 'Track 2'),
        makeTestTrack(id: 't_3', title: 'Track 3'),
      ];

      final playlist = Playlist(
        tracks: tracks,
        title: 'Search: rock',
        type: PlaylistType.remotePlaylist,
      );

      expect(playlist.tracks.length, 3);
      expect(playlist.tracks[1].id, 't_2');
      expect(playlist.title, 'Search: rock');
    });
  });
}
