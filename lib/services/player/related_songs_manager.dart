import 'dart:developer';
import 'package:Bloomee/core/constants/setting_keys.dart';
import 'package:Bloomee/core/di/service_locator.dart';
import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/services/db/dao/settings_dao.dart';
import 'package:Bloomee/services/db/db_provider.dart';
import 'package:Bloomee/services/player/player_engine.dart';
import 'package:Bloomee/services/player/queue_manager.dart';
import 'package:Bloomee/services/plugin/plugin_service.dart';
import 'package:Bloomee/services/recommendation/hybrid_recommendation_engine.dart';
import 'package:Bloomee/services/recommendation/models/recommendation_models.dart';
import 'package:rxdart/rxdart.dart';

/// Coordinates Infinite Radio sessions and intelligent continuous queue replenishment.
///
/// Binds to [HybridRecommendationEngine] to dynamically generate and buffer relevant,
/// personalized tracks without blocking audio playback.
class RelatedSongsManager {
  // Legacy compatibility stream
  final BehaviorSubject<List<Track>> relatedSongs =
      BehaviorSubject<List<Track>>.seeded([]);

  // Reactive Infinite Radio state
  final BehaviorSubject<bool> isRadioActive = BehaviorSubject.seeded(false);
  final BehaviorSubject<RadioSeed?> activeRadioSeed = BehaviorSubject.seeded(null);
  final BehaviorSubject<bool> isGeneratingRadio = BehaviorSubject.seeded(false);
  final BehaviorSubject<String?> radioError = BehaviorSubject.seeded(null);

  final PluginService _pluginService;
  final HybridRecommendationEngine? _engine;

  // Session tracking to prevent duplicates and distinguish manual vs radio tracks
  final Set<String> _sessionTrackIds = <String>{};
  final Set<String> _radioTrackIds = <String>{};
  final Set<String> _manualTrackIds = <String>{};
  final Map<String, RecommendationReason> _trackReasons = <String, RecommendationReason>{};

  String? _nextPageToken;
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;

  // Callbacks
  Function(List<Track> items, {bool atLast})? onAddQueueItems;

  RelatedSongsManager(
    this._pluginService, {
    HybridRecommendationEngine? recommendationEngine,
  }) : _engine = recommendationEngine;

  bool isRadioTrack(String trackId) => _radioTrackIds.contains(trackId);
  void markManualTrack(String trackId) => _manualTrackIds.add(trackId);
  RecommendationReason? getReason(String trackId) => _trackReasons[trackId];
  Set<String> get radioTrackIds => Set.unmodifiable(_radioTrackIds);
  PluginService get pluginService => _pluginService;

  /// Starts an Infinite Radio session with a given track or artist seed.
  Future<List<Track>> startRadio({
    required RadioSeed seed,
    Track? currentTrack,
    List<Track>? initialTracks,
    bool playImmediately = true,
  }) async {
    isRadioActive.add(true);
    activeRadioSeed.add(seed);
    radioError.add(null);
    _sessionTrackIds.clear();
    _radioTrackIds.clear();
    _trackReasons.clear();
    _consecutiveFailures = 0;
    _lastFailureTime = null;
    _nextPageToken = null;

    if (seed.type == RadioSeedType.track) {
      _sessionTrackIds.add(seed.id);
    }
    if (currentTrack != null) {
      _sessionTrackIds.add(currentTrack.id);
    }

    isGeneratingRadio.add(true);
    try {
      final engine = _engine ?? ServiceLocator.recommendationEngine;
      final batch = await engine.getRadioTracksForSeed(
        seed: seed,
        limit: 10,
        pageToken: null,
        excludedTrackIds: _sessionTrackIds,
      );

      final newTracks = <Track>[];
      for (final scored in batch.tracks) {
        if (_sessionTrackIds.add(scored.track.id)) {
          _radioTrackIds.add(scored.track.id);
          _trackReasons[scored.track.id] = scored.reason;
          newTracks.add(scored.track);
        }
      }

      _nextPageToken = batch.nextPageToken;
      log('Infinite Radio started with seed "${seed.title}". Generated ${newTracks.length} initial tracks.',
          name: 'RelatedSongsManager');
      return newTracks;
    } catch (e) {
      log('Failed to start Infinite Radio: $e', name: 'RelatedSongsManager');
      radioError.add('Could not load radio tracks: $e');
      return [];
    } finally {
      isGeneratingRadio.add(false);
    }
  }

  /// Stops Infinite Radio mode. Does NOT stop playback of the currently playing track.
  /// If [clearUpcoming] is true and [queueManager] is provided, only upcoming auto-generated
  /// radio tracks are removed from the queue, preserving manual additions.
  void stopRadio({bool clearUpcoming = false, QueueManager? queueManager}) {
    if (clearUpcoming && queueManager != null && _radioTrackIds.isNotEmpty) {
      queueManager.removeUpcomingTracks(_radioTrackIds);
      _radioTrackIds.clear();
    }
    isRadioActive.add(false);
    activeRadioSeed.add(null);
    _nextPageToken = null;
    radioError.add(null);
    log('Infinite Radio stopped.', name: 'RelatedSongsManager');
  }

  /// Checks the queue buffer and replenishes upcoming tracks when reaching the low-water mark.
  Future<void> checkForRelatedSongs({
    required Track currentMedia,
    required List<Track> queue,
    required int currentPlayingIdx,
    required LoopMode loopMode,
  }) async {
    // If radio is inactive, check legacy auto-play setting
    if (!isRadioActive.value) {
      final autoPlay =
          await SettingsDAO(DBProvider.db).getSettingBool(SettingKeys.autoPlay);
      if (autoPlay != true) return;
    }

    // Low-water mark: replenish when remaining upcoming tracks < 3 and loopMode is not one
    final remainingTracks = queue.length - 1 - currentPlayingIdx;
    if (remainingTracks >= 3 || loopMode == LoopMode.one) {
      return;
    }

    // Mutex guard against concurrent requests
    if (isGeneratingRadio.value) return;

    // Circuit breaker / backoff for repeated network/source errors
    if (_consecutiveFailures >= 3 && _lastFailureTime != null) {
      final diff = DateTime.now().difference(_lastFailureTime!);
      if (diff < const Duration(seconds: 15)) {
        return;
      }
    }

    isGeneratingRadio.add(true);
    try {
      final seed = activeRadioSeed.value ?? RadioSeed.fromTrack(currentMedia);
      final engine = _engine ?? ServiceLocator.recommendationEngine;

      final existingQueueIds = queue.map((t) => t.id).toSet();
      final excluded = {..._sessionTrackIds, ...existingQueueIds};

      final batch = await engine.getRadioTracksForSeed(
        seed: seed,
        limit: 8,
        pageToken: _nextPageToken,
        excludedTrackIds: excluded,
      );

      final candidates = <Track>[];
      for (final scored in batch.tracks) {
        if (_sessionTrackIds.add(scored.track.id) &&
            !existingQueueIds.contains(scored.track.id)) {
          _radioTrackIds.add(scored.track.id);
          _trackReasons[scored.track.id] = scored.reason;
          candidates.add(scored.track);
        }
      }

      if (candidates.isNotEmpty) {
        _consecutiveFailures = 0;
        _nextPageToken = batch.nextPageToken;
        onAddQueueItems?.call(candidates, atLast: true);
        log('Replenished ${candidates.length} tracks into queue for Radio seed "${seed.title}"',
            name: 'RelatedSongsManager');
      } else {
        _consecutiveFailures++;
        _lastFailureTime = DateTime.now();
      }
    } catch (e) {
      _consecutiveFailures++;
      _lastFailureTime = DateTime.now();
      log('Error replenishing radio queue: $e', name: 'RelatedSongsManager');
    } finally {
      isGeneratingRadio.add(false);
    }
  }

  void clearRelatedSongs() {
    relatedSongs.add([]);
    _sessionTrackIds.clear();
    _radioTrackIds.clear();
    _manualTrackIds.clear();
    _trackReasons.clear();
    _nextPageToken = null;
    _consecutiveFailures = 0;
    _lastFailureTime = null;
    isGeneratingRadio.add(false);
  }

  void dispose() {
    relatedSongs.close();
    isRadioActive.close();
    activeRadioSeed.close();
    isGeneratingRadio.close();
    radioError.close();
  }
}
