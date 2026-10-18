import 'dart:async';
import 'dart:developer';
import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/services/recommendation/hybrid_recommendation_engine.dart';
import 'package:Bloomee/services/recommendation/listening_signal_collector.dart';
import 'package:Bloomee/services/recommendation/models/recommendation_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'recommendation_state.dart';

export 'recommendation_state.dart';

class RecommendationCubit extends Cubit<RecommendationState> {
  final HybridRecommendationEngine _engine;
  final ListeningSignalCollector _collector;
  StreamSubscription<UserTasteProfile>? _profileSub;

  RecommendationCubit({
    required HybridRecommendationEngine engine,
    required ListeningSignalCollector collector,
  })  : _engine = engine,
        _collector = collector,
        super(RecommendationInitial()) {
    _init();
  }

  void _init() {
    loadRecommendations();
    _profileSub = _collector.profileStream.listen((profile) {
      // Re-score recommendations when taste profile updates
      if (state is RecommendationLoaded) {
        loadRecommendations(silent: true);
      }
    });
  }

  Future<void> loadRecommendations({
    bool silent = false,
    Track? seedTrack,
  }) async {
    if (!silent) emit(RecommendationLoading());

    try {
      final collections = await _engine.getDiscoveryCollections(
        seedTrack: seedTrack,
      );

      if (collections.isEmpty) {
        emit(const RecommendationEmpty());
      } else {
        emit(RecommendationLoaded(collections: collections));
      }
    } catch (e) {
      log('Error loading recommendations: $e', name: 'RecommendationCubit');
      emit(RecommendationError('Failed to load recommendations: $e'));
    }
  }

  /// Resets recommendation listening signals, derived taste profile, and affinities.
  /// Preserves liked songs, custom playlists, and downloaded tracks.
  Future<bool> resetTasteProfile() async {
    try {
      emit(RecommendationLoading());
      await _collector.resetTasteProfile();
      await loadRecommendations(silent: false);
      return true;
    } catch (e) {
      log('Error resetting taste profile: $e', name: 'RecommendationCubit');
      emit(RecommendationError('Failed to reset taste profile: $e'));
      return false;
    }
  }

  /// Clears explicitly disliked tracks and blocked artists.
  Future<void> clearDislikes() async {
    await _collector.clearDislikes();
    await loadRecommendations(silent: false);
  }

  Future<void> dislikeTrack(Track track) async {
    _collector.onTrackDisliked(track);

    // Immediately remove from current UI state across all collections
    if (state is RecommendationLoaded) {
      final current = state as RecommendationLoaded;
      final updated = current.collections.filterDisliked(
        dislikedTrackIds: {
          ..._collector.currentProfile.dislikedTrackIds,
          track.id,
        },
        dislikedArtistNames: _collector.currentProfile.dislikedArtistNames,
      );

      if (updated.isEmpty) {
        emit(const RecommendationEmpty());
      } else {
        emit(RecommendationLoaded(collections: updated));
      }
    }

    // Refresh recommendations in background
    unawaited(loadRecommendations(silent: true));
  }

  Future<void> dislikeArtist(String artistName) async {
    _collector.onArtistDisliked(artistName);

    if (state is RecommendationLoaded) {
      final current = state as RecommendationLoaded;
      final updated = current.collections.filterDisliked(
        dislikedTrackIds: _collector.currentProfile.dislikedTrackIds,
        dislikedArtistNames: {
          ..._collector.currentProfile.dislikedArtistNames,
          artistName,
        },
      );

      if (updated.isEmpty) {
        emit(const RecommendationEmpty());
      } else {
        emit(RecommendationLoaded(collections: updated));
      }
    }

    unawaited(loadRecommendations(silent: true));
  }

  void onTrackLiked(Track track, bool isLiked) {
    _collector.onTrackLiked(track, isLiked);
  }

  @override
  Future<void> close() {
    _profileSub?.cancel();
    return super.close();
  }
}
