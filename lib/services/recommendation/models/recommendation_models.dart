import 'dart:convert';
import 'package:Bloomee/core/models/exported.dart';

/// Categories of transparent explainability for recommendations.
enum RecommendationReasonType {
  artistAffinity,
  contentSimilarity,
  recentListening,
  likedTrack,
  languageTrending,
  discoverArtist,
  coldStart,
  offlineLibrary,
}

/// User-facing explainability model explaining why a track was recommended.
class RecommendationReason {
  final RecommendationReasonType type;
  final String description;
  final String? sourceContext;

  const RecommendationReason({
    required this.type,
    required this.description,
    this.sourceContext,
  });

  factory RecommendationReason.artistAffinity(String artistName) {
    return RecommendationReason(
      type: RecommendationReasonType.artistAffinity,
      description: 'Because you listen to $artistName',
      sourceContext: artistName,
    );
  }

  factory RecommendationReason.contentSimilarity(String seedTrackTitle) {
    return RecommendationReason(
      type: RecommendationReasonType.contentSimilarity,
      description: 'Similar to "$seedTrackTitle"',
      sourceContext: seedTrackTitle,
    );
  }

  factory RecommendationReason.recentListening(String? context) {
    return RecommendationReason(
      type: RecommendationReasonType.recentListening,
      description: context != null && context.isNotEmpty
          ? 'Based on your recent listening to $context'
          : 'Based on your recent listening',
      sourceContext: context,
    );
  }

  factory RecommendationReason.likedTrack(String trackTitle) {
    return RecommendationReason(
      type: RecommendationReasonType.likedTrack,
      description: 'Because you liked "$trackTitle"',
      sourceContext: trackTitle,
    );
  }

  factory RecommendationReason.languageTrending(String language) {
    return RecommendationReason(
      type: RecommendationReasonType.languageTrending,
      description: 'Trending in $language',
      sourceContext: language,
    );
  }

  factory RecommendationReason.discoverArtist(String artistName) {
    return RecommendationReason(
      type: RecommendationReasonType.discoverArtist,
      description: 'Discover $artistName',
      sourceContext: artistName,
    );
  }

  factory RecommendationReason.coldStart({String? language}) {
    return RecommendationReason(
      type: RecommendationReasonType.coldStart,
      description: language != null && language.isNotEmpty
          ? 'Popular in $language'
          : 'Featured on TarangX',
      sourceContext: language,
    );
  }

  factory RecommendationReason.offlineLibrary() {
    return const RecommendationReason(
      type: RecommendationReasonType.offlineLibrary,
      description: 'From your offline library',
    );
  }

  @override
  String toString() => 'RecommendationReason(type: $type, description: $description)';
}

/// A track paired with its computed score and explainability metadata.
class ScoredTrack {
  final Track track;
  final double score;
  final RecommendationReason reason;
  final Map<String, double> subScores;

  const ScoredTrack({
    required this.track,
    required this.score,
    required this.reason,
    this.subScores = const {},
  });

  @override
  String toString() =>
      'ScoredTrack(title: ${track.title}, score: ${score.toStringAsFixed(3)}, reason: ${reason.description})';
}

/// Configurable and isolated weights for the hybrid ranking formula.
class RecommendationConfig {
  final double prefWeight;
  final double simWeight;
  final double recWeight;
  final double divWeight;

  final double repeatPenalty2h;
  final double repeatPenalty24h;
  final double repeatPenalty3d;
  final double skipPenalty;

  final int maxTracksPerArtist;
  final double completionThreshold;
  final int earlySkipThresholdSeconds;

  const RecommendationConfig({
    this.prefWeight = 0.35,
    this.simWeight = 0.30,
    this.recWeight = 0.20,
    this.divWeight = 0.15,
    this.repeatPenalty2h = 0.60,
    this.repeatPenalty24h = 0.30,
    this.repeatPenalty3d = 0.10,
    this.skipPenalty = 0.25,
    this.maxTracksPerArtist = 2,
    this.completionThreshold = 0.80,
    this.earlySkipThresholdSeconds = 25,
  }) : assert(prefWeight + simWeight + recWeight + divWeight > 0.99 &&
              prefWeight + simWeight + recWeight + divWeight < 1.01,
              'RecommendationConfig weights must sum to 1.0');
}

/// Listening event type for tracking behavioral signals without storing private data.
enum ListeningEventType {
  start,
  completion,
  skip,
  replay,
  like,
  dislike,
}

/// Event model representing a discrete playback signal.
class ListeningEvent {
  final String trackId;
  final String title;
  final String primaryArtist;
  final String? genre;
  final String? language;
  final DateTime timestamp;
  final ListeningEventType eventType;
  final int durationListenedMs;
  final int totalDurationMs;

  const ListeningEvent({
    required this.trackId,
    required this.title,
    required this.primaryArtist,
    this.genre,
    this.language,
    required this.timestamp,
    required this.eventType,
    this.durationListenedMs = 0,
    this.totalDurationMs = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'trackId': trackId,
      'title': title,
      'primaryArtist': primaryArtist,
      'genre': genre,
      'language': language,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'eventType': eventType.name,
      'durationListenedMs': durationListenedMs,
      'totalDurationMs': totalDurationMs,
    };
  }

  factory ListeningEvent.fromMap(Map<String, dynamic> map) {
    return ListeningEvent(
      trackId: map['trackId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      primaryArtist: map['primaryArtist'] as String? ?? '',
      genre: map['genre'] as String?,
      language: map['language'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      eventType: ListeningEventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => ListeningEventType.start,
      ),
      durationListenedMs: map['durationListenedMs'] as int? ?? 0,
      totalDurationMs: map['totalDurationMs'] as int? ?? 0,
    );
  }
}

/// Aggregated, privacy-preserving taste profile derived from user listening history.
class UserTasteProfile {
  final Map<String, double> artistAffinities;
  final Map<String, double> genreAffinities;
  final Map<String, double> languageAffinities;
  final Set<String> likedTrackIds;
  final Set<String> dislikedTrackIds;
  final Set<String> dislikedArtistNames;
  final Map<String, int> trackPlayCounts;
  final Map<String, int> trackCompletionCounts;
  final Map<String, int> trackSkipCounts;
  final Map<String, DateTime> lastPlayedTimestamps;

  const UserTasteProfile({
    this.artistAffinities = const {},
    this.genreAffinities = const {},
    this.languageAffinities = const {},
    this.likedTrackIds = const {},
    this.dislikedTrackIds = const {},
    this.dislikedArtistNames = const {},
    this.trackPlayCounts = const {},
    this.trackCompletionCounts = const {},
    this.trackSkipCounts = const {},
    this.lastPlayedTimestamps = const {},
  });

  bool get isColdStart =>
      trackPlayCounts.isEmpty && likedTrackIds.isEmpty && artistAffinities.isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'artistAffinities': artistAffinities,
      'genreAffinities': genreAffinities,
      'languageAffinities': languageAffinities,
      'likedTrackIds': likedTrackIds.toList(),
      'dislikedTrackIds': dislikedTrackIds.toList(),
      'dislikedArtistNames': dislikedArtistNames.toList(),
      'trackPlayCounts': trackPlayCounts,
      'trackCompletionCounts': trackCompletionCounts,
      'trackSkipCounts': trackSkipCounts,
      'lastPlayedTimestamps': lastPlayedTimestamps.map(
          (k, v) => MapEntry(k, v.millisecondsSinceEpoch)),
    };
  }

  factory UserTasteProfile.fromMap(Map<String, dynamic> map) {
    final rawArtists = map['artistAffinities'] as Map? ?? {};
    final rawGenres = map['genreAffinities'] as Map? ?? {};
    final rawLanguages = map['languageAffinities'] as Map? ?? {};
    final rawPlays = map['trackPlayCounts'] as Map? ?? {};
    final rawCompletions = map['trackCompletionCounts'] as Map? ?? {};
    final rawSkips = map['trackSkipCounts'] as Map? ?? {};
    final rawLastPlayed = map['lastPlayedTimestamps'] as Map? ?? {};

    return UserTasteProfile(
      artistAffinities: rawArtists.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      genreAffinities: rawGenres.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      languageAffinities: rawLanguages.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      likedTrackIds: Set<String>.from(map['likedTrackIds'] as List? ?? []),
      dislikedTrackIds: Set<String>.from(map['dislikedTrackIds'] as List? ?? []),
      dislikedArtistNames: Set<String>.from(map['dislikedArtistNames'] as List? ?? []),
      trackPlayCounts: rawPlays.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      trackCompletionCounts: rawCompletions.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      trackSkipCounts: rawSkips.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      lastPlayedTimestamps: rawLastPlayed.map((k, v) =>
          MapEntry(k.toString(), DateTime.fromMillisecondsSinceEpoch((v as num).toInt()))),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserTasteProfile.fromJson(String jsonStr) {
    try {
      return UserTasteProfile.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return const UserTasteProfile();
    }
  }

  UserTasteProfile copyWith({
    Map<String, double>? artistAffinities,
    Map<String, double>? genreAffinities,
    Map<String, double>? languageAffinities,
    Set<String>? likedTrackIds,
    Set<String>? dislikedTrackIds,
    Set<String>? dislikedArtistNames,
    Map<String, int>? trackPlayCounts,
    Map<String, int>? trackCompletionCounts,
    Map<String, int>? trackSkipCounts,
    Map<String, DateTime>? lastPlayedTimestamps,
  }) {
    return UserTasteProfile(
      artistAffinities: artistAffinities ?? this.artistAffinities,
      genreAffinities: genreAffinities ?? this.genreAffinities,
      languageAffinities: languageAffinities ?? this.languageAffinities,
      likedTrackIds: likedTrackIds ?? this.likedTrackIds,
      dislikedTrackIds: dislikedTrackIds ?? this.dislikedTrackIds,
      dislikedArtistNames: dislikedArtistNames ?? this.dislikedArtistNames,
      trackPlayCounts: trackPlayCounts ?? this.trackPlayCounts,
      trackCompletionCounts: trackCompletionCounts ?? this.trackCompletionCounts,
      trackSkipCounts: trackSkipCounts ?? this.trackSkipCounts,
      lastPlayedTimestamps: lastPlayedTimestamps ?? this.lastPlayedTimestamps,
    );
  }
}
