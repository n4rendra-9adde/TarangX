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
      var profile = raw != null ? UserTasteProfile.fromJson(raw) : const UserTasteProfile();

      // Synchronize with existing Liked tracks from PlaylistDAO
      final likedPlaylist = await _playlistDao.loadPlaylist(PlaylistDAO.likedPlaylist);
      final likedTracks = likedPlaylist.tracks;
      final likedIds = likedTracks.map((t) => t.id).toSet();

      // Synchronize with existing recent history from HistoryDAO
      final history = await _historyDao.getHistory(limit: 50);

      final updatedPlayCounts = Map<String, int>.from(profile.trackPlayCounts);
      final updatedAffinities = Map<String, double>.from(profile.artistAffinities);
      final updatedLastPlayed = Map<String, DateTime>.from(profile.lastPlayedTimestamps);

      for (final track in history) {
        updatedPlayCounts[track.id] = (updatedPlayCounts[track.id] ?? 0) + 1;
        for (final artist in track.artists) {
          if (artist.name.trim().isNotEmpty) {
            final name = artist.name.trim();
            updatedAffinities[name] = (updatedAffinities[name] ?? 0.0) + 0.1;
          }
        }
      }

      // Add extra artist affinity for liked songs
      for (final track in likedTracks) {
        for (final artist in track.artists) {
          if (artist.name.trim().isNotEmpty) {
            final name = artist.name.trim();
            updatedAffinities[name] = (updatedAffinities[name] ?? 0.0) + 0.5;
          }
        }
      }

      // Read disliked tracks / artists
      final dislikedRaw = await _settingsDao.getSettingStr(SettingKeys.dislikedTrackIds);
      final dislikedArtistRaw = await _settingsDao.getSettingStr(SettingKeys.dislikedArtistNames);

      final dislikedTracks = dislikedRaw != null && dislikedRaw.isNotEmpty
          ? Set<String>.from((dislikedRaw.split(',')).map((s) => s.trim()).where((s) => s.isNotEmpty))
          : <String>{};
      final dislikedArtists = dislikedArtistRaw != null && dislikedArtistRaw.isNotEmpty
          ? Set<String>.from((dislikedArtistRaw.split(',')).map((s) => s.trim()).where((s) => s.isNotEmpty))
          : <String>{};

      profile = profile.copyWith(
        likedTrackIds: likedIds,
        dislikedTrackIds: dislikedTracks,
        dislikedArtistNames: dislikedArtists,
        trackPlayCounts: updatedPlayCounts,
        artistAffinities: updatedAffinities,
        lastPlayedTimestamps: updatedLastPlayed,
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
    if (_activeTrackId == track.id) return; // Same track continuing

    // Finalize previous track session if active
    _finalizeActiveSession(skipped: true);

    _activeTrackId = track.id;
    _activeTrack = track;
    _activeTrackStartTime = DateTime.now();
    _maxPositionMs = 0;
    _completionRecorded = false;

    // Increment play count & update last played timestamp
    final profile = currentProfile;
    final playCounts = Map<String, int>.from(profile.trackPlayCounts);
    final lastPlayed = Map<String, DateTime>.from(profile.lastPlayedTimestamps);
    final artistAffinities = Map<String, double>.from(profile.artistAffinities);

    playCounts[track.id] = (playCounts[track.id] ?? 0) + 1;
    lastPlayed[track.id] = DateTime.now();

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
    _profileSubject.add(updated);
    _scheduleProfileSave(updated);
  }

  void _scheduleProfileSave(UserTasteProfile profile) {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(seconds: 3), () async {
      try {
        await _settingsDao.putSettingStr(
          SettingKeys.recommendationTasteProfile,
          profile.toJson(),
        );
      } catch (e) {
        log('Failed to persist taste profile: $e', name: 'ListeningSignalCollector');
      }
    });
  }

  void dispose() {
    _saveDebounceTimer?.cancel();
    _profileSubject.close();
  }
}
