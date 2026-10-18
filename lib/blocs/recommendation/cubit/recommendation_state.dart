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
  final DiscoveryCollections collections;

  List<ScoredTrack> get recommendedTracks => collections.madeForYou;
  List<ScoredTrack> get similarTracks => collections.similarToFavorites;
  List<String> get topArtists =>
      collections.discoverArtists.map((a) => a.name).toList();
  bool get isColdStart => collections.isColdStart;

  const RecommendationLoaded({
    required this.collections,
  });

  factory RecommendationLoaded.legacy({
    required List<ScoredTrack> recommendedTracks,
    List<ScoredTrack> similarTracks = const [],
    List<String> topArtists = const [],
    bool isColdStart = false,
  }) {
    return RecommendationLoaded(
      collections: DiscoveryCollections(
        madeForYou: recommendedTracks,
        similarToFavorites: similarTracks,
        discoverArtists: topArtists
            .map((name) => DiscoveryArtist(name: name, reason: 'Top artist'))
            .toList(),
        isColdStart: isColdStart,
      ),
    );
  }

  @override
  List<Object?> get props => [collections];
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
