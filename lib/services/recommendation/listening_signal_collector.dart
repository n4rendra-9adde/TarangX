import 'dart:async';
import 'dart:developer';
import 'package:Bloomee/core/constants/setting_keys.dart';
import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/services/db/dao/history_dao.dart';
import 'package:Bloomee/services/db/dao/playlist_dao.dart';
import 'package:Bloomee/services/db/dao/settings_dao.dart';
import 'package:Bloomee/services/recommendation/models/recommendation_models.dart';
import 'package:rxdart/rxdart.dart';

/// Collects listening signals (start, completion, skip, replay, like/dislike)
/// and derives an updated [UserTasteProfile] without recording any PII.
class ListeningSignalCollector {
  final SettingsDAO _settingsDao;
  final HistoryDAO _historyDao;
  final PlaylistDAO _playlistDao;
  final RecommendationConfig _config;

  final BehaviorSubject<UserTasteProfile> _profileSubject =
      BehaviorSubject<UserTasteProfile>.seeded(const UserTasteProfile());

  Stream<UserTasteProfile> get profileStream => _profileSubject.stream;
  UserTasteProfile get currentProfile => _profileSubject.value;

  // Tracking state for currently active track
  String? _activeTrackId;
  Track? _activeTrack;
  DateTime? _activeTrackStartTime;
  int _maxPositionMs = 0;
  bool _completionRecorded = false;
  Timer? _saveDebounceTimer;

  // Concurrency & duplicate prevention
  int _epoch = 0;
  String? _lastRecordedTrackId;
  DateTime? _lastRecordedStartTime;

  ListeningSignalCollector({
    required SettingsDAO settingsDao,
    required HistoryDAO historyDao,
    required PlaylistDAO playlistDao,
    RecommendationConfig config = const RecommendationConfig(),
  })  : _settingsDao = settingsDao,
        _historyDao = historyDao,
        _playlistDao = playlistDao,
        _config = config {
    _initializeProfile();
  }

  /// Initialize taste profile from persisted storage and existing history/likes.
  Future<void> _initializeProfile() async {
    try {
      final raw = await _settingsDao.getSettingStr(SettingKeys.recommendationTasteProfile);
      final hasSavedProfile = raw != null && raw.trim().isNotEmpty;
      var profile = hasSavedProfile ? UserTasteProfile.fromJson(raw) : const UserTasteProfile();

      // Synchronize with existing Liked tracks from PlaylistDAO
      final likedPlaylist = await _playlistDao.loadPlaylist(PlaylistDAO.likedPlaylist);
      final likedTracks = likedPlaylist.tracks;
      final likedIds = likedTracks.map((t) => t.id).toSet();

      // Read disliked tracks / artists
      final dislikedRaw = await _settingsDao.getSettingStr(SettingKeys.dislikedTrackIds);
      final dislikedArtistRaw = await _settingsDao.getSettingStr(SettingKeys.dislikedArtistNames);

      final dislikedTracks = dislikedRaw != null && dislikedRaw.isNotEmpty
          ? Set<String>.from((dislikedRaw.split(',')).map((s) => s.trim()).where((s) => s.isNotEmpty))
          : <String>{};
      final dislikedArtists = dislikedArtistRaw != null && dislikedArtistRaw.isNotEmpty
          ? Set<String>.from((dislikedArtistRaw.split(',')).map((s) => s.trim()).where((s) => s.isNotEmpty))
          : <String>{};

      Map<String, int> playCounts = Map<String, int>.from(profile.trackPlayCounts);
      Map<String, double> affinities = Map<String, double>.from(profile.artistAffinities);
      Map<String, DateTime> lastPlayed = Map<String, DateTime>.from(profile.lastPlayedTimestamps);

      // Only seed derived signals from history on first-time app setup when no saved profile exists
      if (!hasSavedProfile) {
        final history = await _historyDao.getHistory(limit: 50);
        for (final track in history) {
          playCounts[track.id] = (playCounts[track.id] ?? 0) + 1;
          for (final artist in track.artists) {
            if (artist.name.trim().isNotEmpty) {
              final name = artist.name.trim();
              affinities[name] = (affinities[name] ?? 0.0) + 0.1;
            }
          }
        }
        for (final track in likedTracks) {
          for (final artist in track.artists) {
            if (artist.name.trim().isNotEmpty) {
              final name = artist.name.trim();
              affinities[name] = (affinities[name] ?? 0.0) + 0.5;
            }
          }
        }
      }

      profile = profile.copyWith(
        likedTrackIds: likedIds,
        dislikedTrackIds: dislikedTracks,
        dislikedArtistNames: dislikedArtists,
        trackPlayCounts: playCounts,
        artistAffinities: affinities,
        lastPlayedTimestamps: lastPlayed,
      );

      _profileSubject.add(profile);
      log('User taste profile initialized (artists: ${profile.artistAffinities.length}, liked: ${profile.likedTrackIds.length})',
          name: 'ListeningSignalCollector');
    } catch (e) {
      log('Failed to initialize taste profile: $e', name: 'ListeningSignalCollector');
    }
  }

  /// Called when a track starts playing in the audio engine.
  void onTrackStarted(Track track) {
    if (track.id.isEmpty) return;
    if (_activeTrackId == track.id) return; // Same track continuing

    final now = DateTime.now();

    // Prevent duplicate track-start events in rapid succession (e.g. within 3s)
    // for the same track caused by buffering retries or seek-on-start
    if (_lastRecordedTrackId == track.id && _lastRecordedStartTime != null) {
      final diff = now.difference(_lastRecordedStartTime!);
      if (diff < const Duration(seconds: 3)) {
        return;
      }
    }

    // Finalize previous track session if active
    _finalizeActiveSession(skipped: true);

    _activeTrackId = track.id;
    _activeTrack = track;
    _activeTrackStartTime = now;
    _lastRecordedTrackId = track.id;
    _lastRecordedStartTime = now;
    _maxPositionMs = 0;
    _completionRecorded = false;

    // Increment play count & update last played timestamp
    final profile = currentProfile;
    final playCounts = Map<String, int>.from(profile.trackPlayCounts);
    final lastPlayed = Map<String, DateTime>.from(profile.lastPlayedTimestamps);
    final artistAffinities = Map<String, double>.from(profile.artistAffinities);

    playCounts[track.id] = (playCounts[track.id] ?? 0) + 1;
    lastPlayed[track.id] = now;

    for (final artist in track.artists) {
      final name = artist.name.trim();
      if (name.isNotEmpty) {
        artistAffinities[name] = (artistAffinities[name] ?? 0.0) + 0.05;
      }
    }

    _updateProfile(profile.copyWith(
      trackPlayCounts: playCounts,
      lastPlayedTimestamps: lastPlayed,
      artistAffinities: artistAffinities,
    ));
  }

  /// Called periodically as playback position advances.
  void onPositionUpdate(Duration position, Duration totalDuration) {
    if (_activeTrack == null || _completionRecorded) return;

    final currMs = position.inMilliseconds;
    if (currMs > _maxPositionMs) {
      _maxPositionMs = currMs;
    }

    final totalMs = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds
        : (_activeTrack?.durationMs?.toInt() ?? 0);

    if (totalMs > 0) {
      final ratio = _maxPositionMs / totalMs;
      if (ratio >= _config.completionThreshold) {
        _completionRecorded = true;
        _recordTrackCompletion(_activeTrack!);
      }
    }
  }

  void _recordTrackCompletion(Track track) {
    final profile = currentProfile;
    final completions = Map<String, int>.from(profile.trackCompletionCounts);
    final artistAffinities = Map<String, double>.from(profile.artistAffinities);

    completions[track.id] = (completions[track.id] ?? 0) + 1;

    // High positive reinforcement on completion
    for (final artist in track.artists) {
      final name = artist.name.trim();
      if (name.isNotEmpty) {
        artistAffinities[name] = (artistAffinities[name] ?? 0.0) + 0.35;
      }
    }

    _updateProfile(profile.copyWith(
      trackCompletionCounts: completions,
      artistAffinities: artistAffinities,
    ));

    log('Track completed (>=80%): ${track.title}', name: 'ListeningSignalCollector');
  }

  /// Finalizes the current track playback session.
  void onTrackEnded({bool skipped = false}) {
    _finalizeActiveSession(skipped: skipped);
  }

  void _finalizeActiveSession({bool skipped = false}) {
    if (_activeTrack == null || _activeTrackStartTime == null) return;

    final track = _activeTrack!;
    final elapsedMs = DateTime.now().difference(_activeTrackStartTime!).inMilliseconds;
    final totalMs = track.durationMs?.toInt() ?? 0;

    // Check for early skip: played for less than threshold and was not completed
    final earlySkipSec = _config.earlySkipThresholdSeconds;
    final wasEarlySkip = skipped &&
        !_completionRecorded &&
        elapsedMs < (earlySkipSec * 1000) &&
        (totalMs == 0 || elapsedMs < (totalMs * 0.25));

    if (wasEarlySkip) {
      _recordTrackSkip(track);
    }

    _activeTrack = null;
    _activeTrackId = null;
    _activeTrackStartTime = null;
    _maxPositionMs = 0;
    _completionRecorded = false;
  }

  void _recordTrackSkip(Track track) {
    final profile = currentProfile;
    final skips = Map<String, int>.from(profile.trackSkipCounts);
    final artistAffinities = Map<String, double>.from(profile.artistAffinities);

    skips[track.id] = (skips[track.id] ?? 0) + 1;

    // Cautious skip penalty: small reduction in artist affinity only after multiple skips
    for (final artist in track.artists) {
      final name = artist.name.trim();
      if (name.isNotEmpty && (skips[track.id] ?? 0) >= 2) {
        final current = artistAffinities[name] ?? 0.0;
        artistAffinities[name] = (current - 0.10).clamp(0.0, 100.0);
      }
    }

    _updateProfile(profile.copyWith(
      trackSkipCounts: skips,
      artistAffinities: artistAffinities,
    ));

    log('Track skipped early: ${track.title} (total skips: ${skips[track.id]})',
        name: 'ListeningSignalCollector');
  }

  /// Explicit Like signal.
  void onTrackLiked(Track track, bool isLiked) {
    final profile = currentProfile;
    final likedIds = Set<String>.from(profile.likedTrackIds);
    final artistAffinities = Map<String, double>.from(profile.artistAffinities);

    if (isLiked) {
      likedIds.add(track.id);
      for (final artist in track.artists) {
        final name = artist.name.trim();
        if (name.isNotEmpty) {
          artistAffinities[name] = (artistAffinities[name] ?? 0.0) + 0.60;
        }
      }
    } else {
      likedIds.remove(track.id);
      for (final artist in track.artists) {
        final name = artist.name.trim();
        if (name.isNotEmpty) {
          final curr = artistAffinities[name] ?? 0.0;
          artistAffinities[name] = (curr - 0.30).clamp(0.0, 100.0);
        }
      }
    }

    _updateProfile(profile.copyWith(
      likedTrackIds: likedIds,
      artistAffinities: artistAffinities,
    ));
  }

  /// Explicit Dislike / Hide signal.
  void onTrackDisliked(Track track) {
    final profile = currentProfile;
    final dislikedIds = Set<String>.from(profile.dislikedTrackIds);
    final likedIds = Set<String>.from(profile.likedTrackIds);
    final artistAffinities = Map<String, double>.from(profile.artistAffinities);

    dislikedIds.add(track.id);
    likedIds.remove(track.id);

    // Penalize artist affinity on explicit track dislike
    for (final artist in track.artists) {
      final name = artist.name.trim();
      if (name.isNotEmpty) {
        final curr = artistAffinities[name] ?? 0.0;
        artistAffinities[name] = (curr - 0.40).clamp(0.0, 100.0);
      }
    }

    _updateProfile(profile.copyWith(
      dislikedTrackIds: dislikedIds,
      likedTrackIds: likedIds,
      artistAffinities: artistAffinities,
    ));

    // Persist disliked track IDs to DB settings
    unawaited(_settingsDao.putSettingStr(
        SettingKeys.dislikedTrackIds, dislikedIds.join(',')));
  }

  /// Explicit Dislike / Block artist signal.
  void onArtistDisliked(String artistName) {
    final cleanName = artistName.trim();
    if (cleanName.isEmpty) return;

    final profile = currentProfile;
    final dislikedArtists = Set<String>.from(profile.dislikedArtistNames);
    final artistAffinities = Map<String, double>.from(profile.artistAffinities);

    dislikedArtists.add(cleanName);
    artistAffinities[cleanName] = 0.0;

    _updateProfile(profile.copyWith(
      dislikedArtistNames: dislikedArtists,
      artistAffinities: artistAffinities,
    ));

    unawaited(_settingsDao.putSettingStr(
        SettingKeys.dislikedArtistNames, dislikedArtists.join(',')));
  }

  void _updateProfile(UserTasteProfile updated) {
    _epoch++;
    _profileSubject.add(updated);
    _scheduleProfileSave(updated);
  }

  void _scheduleProfileSave(UserTasteProfile profile) {
    _saveDebounceTimer?.cancel();
    final scheduledEpoch = _epoch;
    _saveDebounceTimer = Timer(const Duration(seconds: 3), () async {
      await _saveProfileImmediately(profile, expectedEpoch: scheduledEpoch);
    });
  }

  Future<void> _saveProfileImmediately(
    UserTasteProfile profile, {
    int? expectedEpoch,
  }) async {
    // If epoch changed while waiting, discard stale write
    if (expectedEpoch != null && expectedEpoch != _epoch) return;

    try {
      final jsonStr = profile.toJson();
      if (expectedEpoch != null && expectedEpoch != _epoch) return;
      await _settingsDao.putSettingStr(
        SettingKeys.recommendationTasteProfile,
        jsonStr,
      );
    } catch (e) {
      log('Failed to persist taste profile: $e', name: 'ListeningSignalCollector');
    }
  }

  /// Immediately flushes any pending debounced writes to local database.
  Future<void> flush() async {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;
    await _saveProfileImmediately(currentProfile, expectedEpoch: _epoch);
  }

  /// Safely resets locally stored recommendation-specific signals, derived affinities,
  /// and play counters without deleting liked songs, playlists, or downloads.
  Future<void> resetTasteProfile() async {
    // Invalidate any pending or in-flight debounced writes
    _epoch++;
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;

    // Reset in-memory active tracking session
    _activeTrack = null;
    _activeTrackId = null;
    _activeTrackStartTime = null;
    _lastRecordedTrackId = null;
    _lastRecordedStartTime = null;
    _maxPositionMs = 0;
    _completionRecorded = false;

    // Retain explicit positive likes and explicit dislikes, wipe derived signals
    final preservedLiked = Set<String>.from(currentProfile.likedTrackIds);
    final preservedDislikedTracks = Set<String>.from(currentProfile.dislikedTrackIds);
    final preservedDislikedArtists = Set<String>.from(currentProfile.dislikedArtistNames);

    final cleanProfile = UserTasteProfile(
      likedTrackIds: preservedLiked,
      dislikedTrackIds: preservedDislikedTracks,
      dislikedArtistNames: preservedDislikedArtists,
      artistAffinities: const {},
      trackPlayCounts: const {},
      trackCompletionCounts: const {},
      trackSkipCounts: const {},
      lastPlayedTimestamps: const {},
    );

    // Update in-memory stream subject so UI updates immediately
    _profileSubject.add(cleanProfile);

    // Persist clean profile to disk
    await _saveProfileImmediately(cleanProfile, expectedEpoch: _epoch);
    log('Taste profile reset successfully (liked tracks preserved: ${preservedLiked.length})',
        name: 'ListeningSignalCollector');
  }

  /// Clears explicitly hidden/disliked tracks and blocked artists if requested by user.
  Future<void> clearDislikes() async {
    _epoch++;
    final updated = currentProfile.copyWith(
      dislikedTrackIds: const {},
      dislikedArtistNames: const {},
    );
    _profileSubject.add(updated);

    try {
      await _settingsDao.putSettingStr(SettingKeys.dislikedTrackIds, '');
      await _settingsDao.putSettingStr(SettingKeys.dislikedArtistNames, '');
      await _saveProfileImmediately(updated, expectedEpoch: _epoch);
    } catch (e) {
      log('Failed to clear dislikes: $e', name: 'ListeningSignalCollector');
    }
  }

  void dispose() {
    _saveDebounceTimer?.cancel();
    _profileSubject.close();
  }
}
