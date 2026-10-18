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
      final recommended = await _engine.getRecommendations(
        limit: 15,
        currentTrack: seedTrack,
      );

      final similar = seedTrack != null
          ? await _engine.getSimilarTracks(seedTrack, limit: 10)
          : <ScoredTrack>[];

      // Extract top affinity artists
      final profile = _collector.currentProfile;
      final sortedArtists = profile.artistAffinities.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topArtists = sortedArtists.take(8).map((e) => e.key).toList();

      if (recommended.isEmpty && similar.isEmpty) {
        emit(const RecommendationEmpty());
      } else {
        emit(RecommendationLoaded(
          recommendedTracks: recommended,
          similarTracks: similar,
          topArtists: topArtists,
          isColdStart: profile.isColdStart,
        ));
      }
    } catch (e) {
      log('Error loading recommendations: $e', name: 'RecommendationCubit');
      emit(RecommendationError('Failed to load recommendations: $e'));
    }
  }

  Future<void> dislikeTrack(Track track) async {
    _collector.onTrackDisliked(track);

    // Immediately remove from current UI state
    if (state is RecommendationLoaded) {
      final current = state as RecommendationLoaded;
      final updatedRecommended = current.recommendedTracks
          .where((t) => t.track.id != track.id)
          .toList();
      final updatedSimilar = current.similarTracks
          .where((t) => t.track.id != track.id)
          .toList();

      emit(RecommendationLoaded(
        recommendedTracks: updatedRecommended,
        similarTracks: updatedSimilar,
        topArtists: current.topArtists,
        isColdStart: current.isColdStart,
      ));
    }

    // Refresh recommendations in background
    unawaited(loadRecommendations(silent: true));
  }

  Future<void> dislikeArtist(String artistName) async {
    _collector.onArtistDisliked(artistName);

    if (state is RecommendationLoaded) {
      final current = state as RecommendationLoaded;
      final cleanName = artistName.trim().toLowerCase();
      final updatedRecommended = current.recommendedTracks.where((t) {
        return !t.track.artists.any((a) => a.name.trim().toLowerCase() == cleanName);
      }).toList();

      emit(RecommendationLoaded(
        recommendedTracks: updatedRecommended,
        similarTracks: current.similarTracks,
        topArtists: current.topArtists.where((a) => a.trim().toLowerCase() != cleanName).toList(),
        isColdStart: current.isColdStart,
      ));
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
