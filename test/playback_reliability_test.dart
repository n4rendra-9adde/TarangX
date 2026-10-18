import 'package:flutter_test/flutter_test.dart';
import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/services/player/player_error_handler.dart';
import 'package:Bloomee/services/player/player_engine.dart';
import 'package:Bloomee/services/player/queue_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerErrorHandler Error Categorization & Transient Checks', () {
    late PlayerErrorHandler errorHandler;

    setUp(() {
      errorHandler = PlayerErrorHandler();
    });

    tearDown(() {
      errorHandler.dispose();
    });

    test('categorizes network and connection drops correctly as transient', () {
      final errors = [
        'Connection reset by peer',
        'Broken pipe',
        'Software caused connection abort',
        'Abnormal EOF',
        'TimeoutException after 0:00:10.000000',
        'SocketException: OS Error: Network is unreachable',
      ];

      for (final err in errors) {
        final type = errorHandler.categorizeError(err);
        expect(type, equals(PlayerErrorType.networkDropped),
            reason: 'Failed to categorize "$err" as networkDropped');
        expect(errorHandler.isTransientError(type), isTrue,
            reason: '$type should be transient');
      }
    });

    test('categorizes 403 and expired links correctly as transient', () {
      final errors = [
        'HTTP 403 Forbidden',
        'Server returned 403',
        'Stream URL expired',
        'HTTP 410 Gone',
      ];

      for (final err in errors) {
        final type = errorHandler.categorizeError(err);
        expect(type, equals(PlayerErrorType.sourceExpired),
            reason: 'Failed to categorize "$err" as sourceExpired');
        expect(errorHandler.isTransientError(type), isTrue,
            reason: '$type should be transient');
      }
    });

    test('categorizes missing files, demuxer, and format errors as permanent', () {
      final errors = [
        'File not found: /storage/music/song.mp3',
        'Local file for "Track 1" is missing or deleted from storage.',
        'HTTP 404 Not Found',
        'Cannot find demuxer for format',
        'Failed to decode audio track',
        'unrecognized stream container',
      ];

      for (final err in errors) {
        final type = errorHandler.categorizeError(err);
        expect(type, equals(PlayerErrorType.sourceError),
            reason: 'Failed to categorize "$err" as sourceError');
        expect(errorHandler.isTransientError(type), isFalse,
            reason: '$type should NOT be transient');
      }
    });

    test('categorizes permission errors as permanent', () {
      final errors = [
        'Permission denied to access file',
        'Access denied: read storage permission missing',
      ];

      for (final err in errors) {
        final type = errorHandler.categorizeError(err);
        expect(type, equals(PlayerErrorType.permissionError),
            reason: 'Failed to categorize "$err" as permissionError');
        expect(errorHandler.isTransientError(type), isFalse,
            reason: '$type should NOT be transient');
      }
    });

    test('categorizes buffering errors as transient', () {
      final type = errorHandler.categorizeError('Audio pipeline buffer underrun');
      expect(type, equals(PlayerErrorType.bufferingError));
      expect(errorHandler.isTransientError(type), isTrue);
    });
  });

  group('PlayerErrorHandler Security & Path Sanitization', () {
    test('scrubs signed URLs, tokens, and query parameters from error messages', () {
      const sensitiveMsg =
          'Failed to load https://manifest.googlevideo.com/api/manifest/hls_playlist/expire/1729267200/id/abc123xyz?sig=A1B2C3D4E5F6G7H8&token=super_secret_session_token_9999&key=yt-key-abc';
      final sanitized = PlayerErrorHandler.sanitizeErrorMessage(sensitiveMsg);

      expect(sanitized.contains('sig=A1B2C3D4E5F6G7H8'), isFalse);
      expect(sanitized.contains('super_secret_session_token_9999'), isFalse);
      expect(sanitized.contains('yt-key-abc'), isFalse);
      expect(sanitized.contains('?'), isFalse);
    });

    test('scrubs sensitive Linux home directory username paths', () {
      const pathMsg =
          'Cannot open file at /home/john_developer/.local/share/BloomeeTunes/cache/audio.mp4';
      final sanitized = PlayerErrorHandler.sanitizeErrorMessage(pathMsg);

      expect(sanitized.contains('/home/john_developer'), isFalse);
      expect(sanitized.contains('/home/...'), isTrue);
      expect(sanitized, equals('Cannot open file at /home/.../.local/share/BloomeeTunes/cache/audio.mp4'));
    });
  });

  group('PlayerErrorHandler Sequence Isolation & Cascading Error Suppression', () {
    late PlayerErrorHandler errorHandler;
    const track = Track(
      id: 'test-track-1',
      title: 'Test Song',
      artists: [ArtistSummary(id: '1', name: 'Test Artist')],
      album: AlbumSummary(id: '1', title: 'Test Album', artists: []),
      thumbnail: Artwork(url: '', layout: ImageLayout.square),
      isExplicit: false,
    );

    setUp(() {
      errorHandler = PlayerErrorHandler();
    });

    tearDown(() {
      errorHandler.dispose();
    });

    test('suppresses cascading multi-error bursts belonging to the same attempt', () {
      int skipCount = 0;
      errorHandler.onSkipToNext = () => skipCount++;

      errorHandler.registerAttempt(track.id);

      // Trigger 5 consecutive error callbacks for the same attempt (common libmpv behavior)
      for (int i = 0; i < 5; i++) {
        errorHandler.handleError(
          PlayerErrorType.sourceError,
          'Demuxer failed error $i',
          track,
        );
      }

      // Only the first failure in this sequence should be processed
      expect(skipCount, equals(1));
    });

    test('processes errors across distinct attempt sequences', () {
      int skipCount = 0;
      errorHandler.onSkipToNext = () => skipCount++;

      // First attempt
      errorHandler.registerAttempt(track.id);
      errorHandler.handleError(
        PlayerErrorType.sourceError,
        'Demuxer failed',
        track,
      );
      expect(skipCount, equals(1));

      // Second attempt (e.g. after retry or user tapped play again)
      errorHandler.registerAttempt(track.id);
      errorHandler.handleError(
        PlayerErrorType.sourceError,
        'Demuxer failed again',
        track,
      );
      expect(skipCount, equals(2));
    });
  });

  group('PlayerErrorHandler Recovery & Circuit Breaker', () {
    late PlayerErrorHandler errorHandler;
    const track1 = Track(
      id: 'track-1',
      title: 'Track 1',
      artists: [ArtistSummary(id: '1', name: 'Artist 1')],
      album: AlbumSummary(id: '1', title: 'Album 1', artists: []),
      thumbnail: Artwork(url: '', layout: ImageLayout.square),
      isExplicit: false,
    );
    const track2 = Track(
      id: 'track-2',
      title: 'Track 2',
      artists: [ArtistSummary(id: '2', name: 'Artist 2')],
      album: AlbumSummary(id: '2', title: 'Album 2', artists: []),
      thumbnail: Artwork(url: '', layout: ImageLayout.square),
      isExplicit: false,
    );

    setUp(() {
      errorHandler = PlayerErrorHandler();
    });

    tearDown(() {
      errorHandler.dispose();
    });

    test('permanent errors do not retry and immediately invoke skipToNext', () {
      bool skipped = false;
      bool retried = false;

      errorHandler.onSkipToNext = () => skipped = true;
      errorHandler.onRetryCurrentTrack = () => retried = true;

      errorHandler.registerAttempt(track1.id);
      errorHandler.handleError(
        PlayerErrorType.sourceError,
        'File missing on disk',
        track1,
      );

      expect(retried, isFalse);
      expect(skipped, isTrue);
    });

    test('trips circuit breaker after consecutive distinct track total failures', () {
      int skipCount = 0;
      bool circuitBreakerTripped = false;

      errorHandler.onSkipToNext = () => skipCount++;
      errorHandler.onStopPlayback = () => circuitBreakerTripped = true;

      // Fail 4 distinct tracks permanently
      for (int i = 0; i < 4; i++) {
        final t = Track(
          id: 'failed-track-$i',
          title: 'Track $i',
          artists: const [ArtistSummary(id: '1', name: 'Artist')],
          album: const AlbumSummary(id: '1', title: 'Album', artists: []),
          thumbnail: const Artwork(url: '', layout: ImageLayout.square),
          isExplicit: false,
        );
        errorHandler.registerAttempt(t.id);
        errorHandler.handleError(
          PlayerErrorType.sourceError,
          'Permanent failure',
          t,
        );
      }

      // First 3 tracks cause skip, the 4th trips the circuit breaker
      expect(skipCount, equals(3));
      expect(circuitBreakerTripped, isTrue);
    });

    test('markTrackSuccess resets consecutive failure counter', () {
      int skipCount = 0;
      bool circuitBreakerTripped = false;

      errorHandler.onSkipToNext = () => skipCount++;
      errorHandler.onStopPlayback = () => circuitBreakerTripped = true;

      // Fail 2 tracks
      for (int i = 0; i < 2; i++) {
        final t = Track(
          id: 'fail-track-$i',
          title: 'Fail $i',
          artists: const [ArtistSummary(id: '1', name: 'Artist')],
          album: const AlbumSummary(id: '1', title: 'Album', artists: []),
          thumbnail: const Artwork(url: '', layout: ImageLayout.square),
          isExplicit: false,
        );
        errorHandler.registerAttempt(t.id);
        errorHandler.handleError(PlayerErrorType.sourceError, 'Fail', t);
      }
      expect(skipCount, equals(2));

      // Successfully play track2
      errorHandler.registerAttempt(track2.id);
      errorHandler.markTrackSuccess(track2.id);

      // Fail 2 more tracks
      for (int i = 0; i < 2; i++) {
        final t = Track(
          id: 'fail-track-after-$i',
          title: 'Fail After $i',
          artists: const [ArtistSummary(id: '1', name: 'Artist')],
          album: const AlbumSummary(id: '1', title: 'Album', artists: []),
          thumbnail: const Artwork(url: '', layout: ImageLayout.square),
          isExplicit: false,
        );
        errorHandler.registerAttempt(t.id);
        errorHandler.handleError(PlayerErrorType.sourceError, 'Fail', t);
      }

      // Circuit breaker should NOT be tripped because the counter was reset by success
      expect(circuitBreakerTripped, isFalse);
      expect(skipCount, equals(4));
    });

    test('resetCircuitBreaker restores initial clean state', () {
      errorHandler.registerAttempt(track1.id);
      errorHandler.handleError(PlayerErrorType.sourceError, 'Fail', track1);
      expect(errorHandler.lastError.value, isNotNull);

      errorHandler.resetCircuitBreaker();
      expect(errorHandler.lastError.value, isNull);
    });
  });

  group('QueueManager Navigation, Deduplication & Position State', () {
    late QueueManager queueManager;

    final sampleTracks = List.generate(
      5,
      (i) => Track(
        id: 'track-$i',
        title: 'Track $i',
        artists: const [ArtistSummary(id: '1', name: 'Artist')],
        album: const AlbumSummary(id: '1', title: 'Album', artists: []),
        thumbnail: const Artwork(url: '', layout: ImageLayout.square),
        isExplicit: false,
      ),
    );

    setUp(() {
      queueManager = QueueManager();
    });

    tearDown(() {
      queueManager.dispose();
    });

    test('initializes with empty queue and zero restoredPosition', () {
      expect(queueManager.isEmpty, isTrue);
      expect(queueManager.tracks, isEmpty);
      expect(queueManager.currentIndex, equals(0));
      expect(queueManager.restoredPosition, equals(Duration.zero));
    });

    test('loadTracks sets queue and deduplicates items while maintaining start index', () {
      final duplicateList = [
        sampleTracks[0],
        sampleTracks[1],
        sampleTracks[0], // duplicate
        sampleTracks[2],
      ];

      queueManager.loadTracks(duplicateList, idx: 3); // target sampleTracks[2]

      expect(queueManager.length, equals(3));
      expect(queueManager.tracks[0].id, equals('track-0'));
      expect(queueManager.tracks[1].id, equals('track-1'));
      expect(queueManager.tracks[2].id, equals('track-2'));
      // remapped index should point to track-2 at index 2
      expect(queueManager.currentIndex, equals(2));
      expect(queueManager.currentTrack?.id, equals('track-2'));
    });

    test('advanceToNext and advanceToPrevious obey boundaries and LoopMode', () {
      queueManager.loadTracks(sampleTracks, idx: 3);
      expect(queueManager.currentIndex, equals(3));

      // Advance to 4 (last)
      expect(queueManager.hasNext(loopMode: LoopMode.off), isTrue);
      expect(queueManager.advanceToNext(loopMode: LoopMode.off), isTrue);
      expect(queueManager.currentIndex, equals(4));

      // At end with LoopMode.off: cannot advance
      expect(queueManager.hasNext(loopMode: LoopMode.off), isFalse);
      expect(queueManager.advanceToNext(loopMode: LoopMode.off), isFalse);
      expect(queueManager.currentIndex, equals(4));

      // At end with LoopMode.all: wraps to 0
      expect(queueManager.hasNext(loopMode: LoopMode.all), isTrue);
      expect(queueManager.advanceToNext(loopMode: LoopMode.all), isTrue);
      expect(queueManager.currentIndex, equals(0));

      // At start with LoopMode.all: wraps to end (4)
      expect(queueManager.hasPrevious(loopMode: LoopMode.all), isTrue);
      expect(queueManager.advanceToPrevious(loopMode: LoopMode.all), isTrue);
      expect(queueManager.currentIndex, equals(4));

      // Step back towards 0
      expect(queueManager.advanceToPrevious(loopMode: LoopMode.off), isTrue);
      expect(queueManager.currentIndex, equals(3));
    });

    test('peekNext previews next song without moving queue index', () {
      queueManager.loadTracks(sampleTracks, idx: 1);
      final nextTrack = queueManager.peekNext(loopMode: LoopMode.off);

      expect(nextTrack?.id, equals('track-2'));
      expect(queueManager.currentIndex, equals(1)); // Unchanged
    });
  });

  group('PlayerEngine LoopMode & State Constants', () {
    test('EngineState transitions covers standard lifecycle states', () {
      const states = [
        EngineState.idle,
        EngineState.loading,
        EngineState.buffering,
        EngineState.ready,
        EngineState.completed,
        EngineState.error,
      ];
      expect(states.length, equals(6));
    });

    test('LoopMode values include off, all, and one', () {
      expect(LoopMode.values, containsAll([LoopMode.off, LoopMode.all, LoopMode.one]));
    });
  });
}
