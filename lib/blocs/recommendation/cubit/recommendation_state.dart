import 'package:equatable/equatable.dart';
import 'package:Bloomee/services/recommendation/models/recommendation_models.dart';

abstract class RecommendationState extends Equatable {
  const RecommendationState();

  @override
  List<Object?> get props => [];
}

class RecommendationInitial extends RecommendationState {}

class RecommendationLoading extends RecommendationState {}

class RecommendationLoaded extends RecommendationState {
  final List<ScoredTrack> recommendedTracks;
  final List<ScoredTrack> similarTracks;
  final List<String> topArtists;
  final bool isColdStart;

  const RecommendationLoaded({
    required this.recommendedTracks,
    this.similarTracks = const [],
    this.topArtists = const [],
    this.isColdStart = false,
  });

  @override
  List<Object?> get props => [recommendedTracks, similarTracks, topArtists, isColdStart];
}

class RecommendationEmpty extends RecommendationState {
  final String message;

  const RecommendationEmpty({
    this.message = 'No recommendations available right now.',
  });

  @override
  List<Object?> get props => [message];
}

class RecommendationError extends RecommendationState {
  final String message;

  const RecommendationError(this.message);

  @override
  List<Object?> get props => [message];
}
