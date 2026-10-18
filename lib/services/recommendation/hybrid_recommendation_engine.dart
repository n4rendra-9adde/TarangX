import 'dart:developer';
import 'dart:math' as math;
import 'package:Bloomee/core/constants/setting_keys.dart';
import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/screens/widgets/language_selection_modals.dart';
import 'package:Bloomee/services/db/dao/download_dao.dart';
import 'package:Bloomee/services/db/dao/history_dao.dart';
import 'package:Bloomee/services/db/dao/playlist_dao.dart';
import 'package:Bloomee/services/db/dao/settings_dao.dart';
import 'package:Bloomee/services/plugin/plugin_service.dart';
import 'package:Bloomee/services/recommendation/listening_signal_collector.dart';
import 'package:Bloomee/services/recommendation/models/recommendation_models.dart';
import 'package:Bloomee/src/rust/api/plugin/commands.dart';
import 'package:Bloomee/plugins/utils/media_id.dart';

/// Transparent, deterministic hybrid music recommendation engine for TarangX.
class HybridRecommendationEngine {
  final ListeningSignalCollector _signalCollector;
  final HistoryDAO _historyDao;
  final PlaylistDAO _playlistDao;
  final DownloadDAO _downloadDao;
  final SettingsDAO _settingsDao;
  final PluginService _pluginService;
  final RecommendationConfig _config;

  final Map<String, String> _trackLanguageMap = {};

  HybridRecommendationEngine({
    required ListeningSignalCollector signalCollector,
    required HistoryDAO historyDao,
    required PlaylistDAO playlistDao,
    required DownloadDAO downloadDao,
    required SettingsDAO settingsDao,
    required PluginService pluginService,
    RecommendationConfig config = const RecommendationConfig(),
  })  : _signalCollector = signalCollector,
        _historyDao = historyDao,
        _playlistDao = playlistDao,
        _downloadDao = downloadDao,
        _settingsDao = settingsDao,
        _pluginService = pluginService,
        _config = config;

  /// Generate personalized recommendations for the user.
  Future<List<ScoredTrack>> getRecommendations({
    int limit = 15,
    Track? currentTrack,
  }) async {
    final profile = _signalCollector.currentProfile;
    final userLanguages = await _getUserMusicLanguages();

    // 1. Gather candidates from multiple local and online sources
    final candidatePool = await _gatherCandidatePool(
      profile: profile,
      userLanguages: userLanguages,
      seedTrack: currentTrack,
    );

    if (candidatePool.isEmpty) {
      log('No recommendation candidates available', name: 'HybridRecommendationEngine');
      return [];
    }

    // 2. Filter out explicit dislikes, blocked artists, and malformed tracks
    final validCandidates = _filterCandidates(candidatePool, profile);

    // 3. Compute deterministic scores and explainability reasons
    final scoredList = <ScoredTrack>[];
    for (final candidate in validCandidates) {
      final scored = scoreCandidate(
        candidate: candidate,
        profile: profile,
        seedTrack: currentTrack,
        userLanguages: userLanguages,
      );
      if (scored.score > 0.0) {
        scoredList.add(scored);
      }
    }

    // Sort by score descending
    scoredList.sort((a, b) => b.score.compareTo(a.score));

    // 4. Enforce catalog diversity (limit tracks per artist to prevent saturation)
    final diversified = _applyDiversityAndDeduplication(
      scoredList,
      maxPerArtist: _config.maxTracksPerArtist,
      limit: limit,
    );

    // 5. Final exclusion guarantee: strictly ensure no disliked track or blocked artist is emitted
    final finalRecommendations = diversified
        .where((st) => !isTrackExcluded(st.track, profile) && st.score > 0.0)
        .toList();

    log('Generated ${finalRecommendations.length} personalized recommendations',
        name: 'HybridRecommendationEngine');
    return finalRecommendations;
  }

  /// Generate similar tracks for a specific reference track (e.g. Now Playing).
  Future<List<ScoredTrack>> getSimilarTracks(
    Track referenceTrack, {
    int limit = 10,
  }) async {
    final profile = _signalCollector.currentProfile;
    final userLanguages = await _getUserMusicLanguages();

    final candidates = <Track>[];

    // Try fetching radio tracks via plugin service
    final parts = tryParseMediaId(referenceTrack.id);
    if (parts != null && parts.pluginId != kLocalPluginId) {
      try {
        final response = await _pluginService.execute(
          pluginId: parts.pluginId,
          request: PluginRequest.contentResolver(
            ContentResolverCommand.getRadioTracks(
              id: parts.localId,
              pageToken: null,
            ),
          ),
        );
        response.whenOrNull(
          moreTracks: (paged) {
            candidates.addAll(paged.items);
          },
        );
      } catch (e) {
        log('Plugin radio tracks fetch error: $e', name: 'HybridRecommendationEngine');
      }
    }

    // If online radio returned few tracks, supplement from local history & downloads
    if (candidates.length < limit) {
      try {
        final historyTracks = await _historyDao.getHistory(limit: 30);
        candidates.addAll(historyTracks);
        final downloadedTracks = await _downloadDao.getValidDownloadedTracks();
        candidates.addAll(downloadedTracks);
      } catch (_) {}
    }

    final filtered = _filterCandidates(candidates, profile)
        .where((t) => t.id != referenceTrack.id)
        .toList();

    final scored = filtered.map((c) {
      final simScore = _calculateContentSimilarity(c, referenceTrack);
      final prefScore = _calculatePreferenceScore(c, profile, userLanguages);
      final finalScore = (simScore * 0.70) + (prefScore * 0.30);
      return ScoredTrack(
        track: c,
        score: finalScore,
        reason: RecommendationReason.contentSimilarity(referenceTrack.title),
        subScores: {'similarity': simScore, 'preference': prefScore},
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    final diversified = _applyDiversityAndDeduplication(scored, maxPerArtist: 2, limit: limit);
    return diversified
        .where((st) => !isTrackExcluded(st.track, profile) && st.score > 0.0)
        .toList();
  }

  /// Generates a paginated batch of tracks for an Infinite Radio session
  /// based on a song or artist seed.
  Future<RadioBatchResult> getRadioTracksForSeed({
    required RadioSeed seed,
    int limit = 10,
    String? pageToken,
    Set<String> excludedTrackIds = const {},
  }) async {
    final profile = _signalCollector.currentProfile;
    final userLanguages = await _getUserMusicLanguages();
    final candidates = <Track>[];
    String? nextPageToken;

    if (seed.type == RadioSeedType.track) {
      final parts = tryParseMediaId(seed.id);
      if (parts != null && parts.pluginId != kLocalPluginId) {
        try {
          final response = await _pluginService.execute(
            pluginId: parts.pluginId,
            request: PluginRequest.contentResolver(
              ContentResolverCommand.getRadioTracks(
                id: parts.localId,
                pageToken: pageToken,
              ),
            ),
          );
          response.whenOrNull(
            moreTracks: (paged) {
              candidates.addAll(paged.items);
              nextPageToken = paged.nextPageToken;
            },
          );
        } catch (e) {
          log('Plugin radio tracks error for seed ${seed.title}: $e',
              name: 'HybridRecommendationEngine');
        }
      }
    } else {
      // Artist seed: fetch artist details to extract top tracks as radio candidates
      final parts = tryParseMediaId(seed.id);
      if (parts != null && parts.pluginId != kLocalPluginId) {
        try {
          final response = await _pluginService.execute(
            pluginId: parts.pluginId,
            request: PluginRequest.contentResolver(
              ContentResolverCommand.getArtistDetails(id: parts.localId),
            ),
          );
          response.whenOrNull(
            artistDetails: (details) {
              candidates.addAll(details.topTracks);
            },
          );
        } catch (_) {}
      }
    }

    // If online results are scarce or unavailable, supplement from local library and history
    if (candidates.length < limit) {
      try {
        final likedPlaylist =
            await _playlistDao.loadPlaylist(PlaylistDAO.likedPlaylist);
        candidates.addAll(likedPlaylist.tracks);
        final history = await _historyDao.getHistory(limit: 40);
        candidates.addAll(history);
        final downloads = await _downloadDao.getValidDownloadedTracks();
        candidates.addAll(downloads);
        final curated = _getCuratedLanguageCandidates(userLanguages);
        candidates.addAll(curated);
      } catch (_) {}
    }

    // Filter exclusions, dislikes, seed itself, and already-queued session IDs
    final cleanCandidates = _filterCandidates(candidates, profile).where((t) {
      if (t.id == seed.id) return false;
      if (excludedTrackIds.contains(t.id)) return false;
      return true;
    }).toList();

    final scored = cleanCandidates.map((c) {
      double simScore;
      if (seed.type == RadioSeedType.track) {
        simScore = c.artists.any((a) =>
                seed.subtitle?.toLowerCase().contains(a.name.toLowerCase().trim()) ?? false)
            ? 0.85
            : 0.40;
      } else {
        simScore = c.artists.any((a) =>
                a.name.toLowerCase().trim() == seed.title.toLowerCase().trim())
            ? 0.95
            : 0.35;
      }

      final prefScore = _calculatePreferenceScore(c, profile, userLanguages);
      final recScore = _calculateRecencyScore(c, profile);
      final repPenalty = _calculateRepetitionPenalty(c, profile);

      final finalScore =
          (simScore * 0.50) + (prefScore * 0.35) + (recScore * 0.15) - repPenalty;

      return ScoredTrack(
        track: c,
        score: finalScore.clamp(0.01, 1.0),
        reason: RecommendationReason.infiniteRadio(seed.title),
        subScores: {'similarity': simScore, 'preference': prefScore},
      );
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    final diversified = _applyDiversityAndDeduplication(scored,
        maxPerArtist: _config.maxTracksPerArtist, limit: limit);

    final finalTracks = diversified
        .where((st) => !isTrackExcluded(st.track, profile) && st.score > 0.0)
        .toList();

    return RadioBatchResult(
      tracks: finalTracks,
      nextPageToken: nextPageToken,
      isExhausted: nextPageToken == null && finalTracks.isEmpty,
    );
  }

  /// Evaluates whether a track is explicitly excluded (disliked track ID or blocked artist).
  /// Exclusions are case-insensitive and take absolute precedence over positive preferences.
  bool isTrackExcluded(Track track, UserTasteProfile profile) {
    if (track.id.isEmpty) return true;
    if (profile.dislikedTrackIds.contains(track.id)) return true;

    if (profile.dislikedArtistNames.isEmpty) return false;

    final dislikedArtists = profile.dislikedArtistNames
        .map((a) => a.trim().toLowerCase())
        .where((a) => a.isNotEmpty)
        .toSet();

    for (final artist in track.artists) {
      final name = artist.name.trim().toLowerCase();
      if (name.isNotEmpty && dislikedArtists.contains(name)) {
        return true;
      }
    }
    return false;
  }

  /// Computes deterministic hybrid score for a single candidate track.
  ScoredTrack scoreCandidate({
    required Track candidate,
    required UserTasteProfile profile,
    Track? seedTrack,
    List<String> userLanguages = const [],
  }) {
    // Hard filter: Disliked tracks or blocked artists get 0.0
    if (isTrackExcluded(candidate, profile)) {
      return ScoredTrack(
        track: candidate,
        score: 0.0,
        reason: const RecommendationReason(
          type: RecommendationReasonType.coldStart,
          description: 'Excluded',
        ),
      );
    }

    // 1. User Preference Score (0.0 to 1.0)
    final prefScore = _calculatePreferenceScore(candidate, profile, userLanguages);

    // 2. Content Similarity Score (0.0 to 1.0)
    final simScore = seedTrack != null
        ? _calculateContentSimilarity(candidate, seedTrack)
        : _calculateHistorySimilarity(candidate, profile);

    // 3. Recency & Context Score (0.0 to 1.0)
    final recScore = _calculateRecencyScore(candidate, profile);

    // 4. Catalog Diversity Bonus (0.0 to 1.0)
    final divScore = _calculateDiversityBonus(candidate, profile, userLanguages);

    // 5. Penalties (Repetition & Skips)
    final repPenalty = _calculateRepetitionPenalty(candidate, profile);
    final skipPenalty = _calculateSkipPenalty(candidate, profile);

    // Hybrid Combination
    double rawScore = (_config.prefWeight * prefScore) +
        (_config.simWeight * simScore) +
        (_config.recWeight * recScore) +
        (_config.divWeight * divScore) -
        repPenalty -
        skipPenalty;

    final finalScore = rawScore.clamp(0.0, 1.0);

    // Determine honest explainability reason based on dominant signal
    final reason = _determineExplanationReason(
      candidate: candidate,
      profile: profile,
      seedTrack: seedTrack,
      prefScore: prefScore,
      simScore: simScore,
      divScore: divScore,
      userLanguages: userLanguages,
    );

    return ScoredTrack(
      track: candidate,
      score: finalScore,
      reason: reason,
      subScores: {
        'preference': prefScore,
        'similarity': simScore,
        'recency': recScore,
        'diversity': divScore,
        'repeatPenalty': repPenalty,
        'skipPenalty': skipPenalty,
      },
    );
  }

  // ── Candidate Generation ──────────────────────────────────────────────────

  Future<List<Track>> _gatherCandidatePool({
    required UserTasteProfile profile,
    required List<String> userLanguages,
    Track? seedTrack,
  }) async {
    final pool = <Track>[];
    final seenIds = <String>{};

    void addUnique(List<Track> tracks) {
      for (final t in tracks) {
        if (t.id.isNotEmpty && seenIds.add(t.id)) {
          pool.add(t);
        }
      }
    }

    // 1. Liked Tracks (high value seeds)
    try {
      final likedPlaylist = await _playlistDao.loadPlaylist(PlaylistDAO.likedPlaylist);
      addUnique(likedPlaylist.tracks);
    } catch (_) {}

    // 2. Playback History
    try {
      final history = await _historyDao.getHistory(limit: 60);
      addUnique(history);
    } catch (_) {}

    // 3. Offline / Downloaded tracks (critical for offline mode)
    try {
      final downloads = await _downloadDao.getValidDownloadedTracks();
      addUnique(downloads);
    } catch (_) {}

    // 4. Online Radio / Related tracks for top artists/tracks
    if (seedTrack != null) {
      final radioTracks = await _fetchRadioCandidates(seedTrack);
      addUnique(radioTracks);
    } else if (pool.isNotEmpty) {
      // Pick top played track as radio seed
      final topSeed = pool.first;
      final radioTracks = await _fetchRadioCandidates(topSeed);
      addUnique(radioTracks);
    }

    // 5. Curated Language Catalog (for diversity & cold-start)
    final curatedTracks = _getCuratedLanguageCandidates(userLanguages);
    addUnique(curatedTracks);

    return pool;
  }

  Future<List<Track>> _fetchRadioCandidates(Track seed) async {
    final parts = tryParseMediaId(seed.id);
    if (parts == null || parts.pluginId == kLocalPluginId) return [];

    try {
      final response = await _pluginService.execute(
        pluginId: parts.pluginId,
        request: PluginRequest.contentResolver(
          ContentResolverCommand.getRadioTracks(
            id: parts.localId,
            pageToken: null,
          ),
        ),
      );
      List<Track> results = [];
      response.whenOrNull(
        moreTracks: (paged) {
          results = paged.items;
        },
      );
      return results;
    } catch (e) {
      return [];
    }
  }

  List<Track> _getCuratedLanguageCandidates(List<String> languages) {
    final tracks = <Track>[];
    final targetLanguages = languages.isNotEmpty ? languages : ['Hindi', 'English'];

    for (final playlist in kCuratedLanguagePlaylists) {
      if (targetLanguages.contains(playlist.language)) {
        final track = Track(
          id: 'curated:${playlist.id}',
          title: playlist.title,
          artists: [
            ArtistSummary(id: '', name: '${playlist.language} Hits'),
          ],
          album: AlbumSummary(id: '', title: playlist.title, artists: const []),
          thumbnail: Artwork(url: playlist.coverUrl, layout: ImageLayout.square),
          isExplicit: false,
        );
        _trackLanguageMap[track.id] = playlist.language;
        tracks.add(track);
      }
    }
    return tracks;
  }

  // ── Candidate Filtering & Deduplication ───────────────────────────────────

  List<Track> _filterCandidates(List<Track> candidates, UserTasteProfile profile) {
    final filtered = <Track>[];
    final seenNormalizedTitles = <String>{};

    for (final track in candidates) {
      if (track.id.isEmpty || track.title.trim().isEmpty) continue;

      // Disliked track or blocked artist (case-insensitive)
      if (isTrackExcluded(track, profile)) continue;

      // Deduplicate by normalized Title + Primary Artist
      final primaryArtist = track.artists.isNotEmpty ? track.artists.first.name.trim().toLowerCase() : '';
      final normKey = '${track.title.trim().toLowerCase()}__$primaryArtist';
      if (!seenNormalizedTitles.add(normKey)) continue;

      filtered.add(track);
    }
    return filtered;
  }

  List<ScoredTrack> _applyDiversityAndDeduplication(
    List<ScoredTrack> list, {
    int maxPerArtist = 2,
    required int limit,
  }) {
    final result = <ScoredTrack>[];
    final artistCounts = <String, int>{};

    for (final item in list) {
      final primaryArtist = item.track.artists.isNotEmpty
          ? item.track.artists.first.name.trim().toLowerCase()
          : 'unknown';

      final count = artistCounts[primaryArtist] ?? 0;
      if (count >= maxPerArtist) continue;

      result.add(item);
      artistCounts[primaryArtist] = count + 1;

      if (result.length >= limit) break;
    }
    return result;
  }

  // ── Scoring Sub-functions ─────────────────────────────────────────────────

  double _calculatePreferenceScore(
    Track candidate,
    UserTasteProfile profile,
    List<String> userLanguages,
  ) {
    if (profile.isColdStart) {
      // In cold start: boost tracks matching user's selected languages
      final lang = _trackLanguageMap[candidate.id];
      if (lang != null && userLanguages.contains(lang)) {
        return 0.85;
      }
      return 0.50;
    }

    double score = 0.0;

    // Explicit like bonus
    if (profile.likedTrackIds.contains(candidate.id)) {
      score += 0.50;
    }

    // Artist affinity bonus
    double maxArtistAffinity = 0.0;
    for (final artist in candidate.artists) {
      final affinity = profile.artistAffinities[artist.name.trim()] ?? 0.0;
      if (affinity > maxArtistAffinity) maxArtistAffinity = affinity;
    }
    // Normalize affinity logarithmically to [0.0, 0.40]
    final normalizedAffinity = (math.log(1.0 + maxArtistAffinity) / 3.0).clamp(0.0, 0.40);
    score += normalizedAffinity;

    // Completion ratio bonus
    final plays = profile.trackPlayCounts[candidate.id] ?? 0;
    final completions = profile.trackCompletionCounts[candidate.id] ?? 0;
    if (plays > 0) {
      final completionRatio = (completions / plays).clamp(0.0, 1.0);
      score += completionRatio * 0.10;
    }

    return score.clamp(0.0, 1.0);
  }

  double _calculateContentSimilarity(Track candidate, Track seed) {
    double score = 0.0;

    // 1. Artist overlap
    final seedArtists = seed.artists.map((a) => a.name.trim().toLowerCase()).toSet();
    final candidateArtists = candidate.artists.map((a) => a.name.trim().toLowerCase()).toSet();

    if (candidateArtists.intersection(seedArtists).isNotEmpty) {
      score += 0.55; // Shared artist
    }

    // 2. Album match
    if (candidate.album != null &&
        seed.album != null &&
        candidate.album!.title.trim().isNotEmpty &&
        candidate.album!.title.toLowerCase() == seed.album!.title.toLowerCase()) {
      score += 0.20;
    }

    // 3. Language match
    final cLang = _trackLanguageMap[candidate.id];
    final sLang = _trackLanguageMap[seed.id];
    if (cLang != null && sLang != null && cLang == sLang) {
      score += 0.15;
    }

    // 4. Duration proximity
    final cDur = candidate.durationMs?.toInt() ?? 0;
    final sDur = seed.durationMs?.toInt() ?? 0;
    if (cDur > 0 && sDur > 0) {
      final diffSec = (cDur - sDur).abs() / 1000;
      if (diffSec <= 45) {
        score += 0.10;
      } else if (diffSec <= 90) {
        score += 0.05;
      }
    } else {
      score += 0.05;
    }

    return score.clamp(0.0, 1.0);
  }

  double _calculateHistorySimilarity(Track candidate, UserTasteProfile profile) {
    if (profile.artistAffinities.isEmpty) return 0.40;

    // Check if candidate's artists are among top affinity artists
    for (final artist in candidate.artists) {
      final affinity = profile.artistAffinities[artist.name.trim()] ?? 0.0;
      if (affinity > 0.5) return 0.85;
      if (affinity > 0.1) return 0.65;
    }
    return 0.30;
  }

  double _calculateRecencyScore(Track candidate, UserTasteProfile profile) {
    final lastPlayed = profile.lastPlayedTimestamps[candidate.id];
    if (lastPlayed == null) {
      return 0.40; // Neutral score for unplayed candidates
    }

    // Exponential decay with half-life of 7 days
    final hoursSincePlay = DateTime.now().difference(lastPlayed).inHours;
    final decay = math.exp(-hoursSincePlay / (7.0 * 24.0));
    return decay.clamp(0.0, 1.0);
  }

  double _calculateDiversityBonus(
    Track candidate,
    UserTasteProfile profile,
    List<String> userLanguages,
  ) {
    final candidateArtists = candidate.artists.map((a) => a.name.trim()).toList();
    final isNewArtist = candidateArtists.every(
      (name) => (profile.artistAffinities[name] ?? 0.0) == 0.0,
    );

    if (isNewArtist) {
      // If new artist matches preferred languages, give discovery bonus
      final lang = _trackLanguageMap[candidate.id];
      final matchesLanguage = lang != null && userLanguages.contains(lang);
      return matchesLanguage ? 0.70 : 0.40;
    }

    return 0.10;
  }

  double _calculateRepetitionPenalty(Track candidate, UserTasteProfile profile) {
    final lastPlayed = profile.lastPlayedTimestamps[candidate.id];
    if (lastPlayed == null) return 0.0;

    final hoursSincePlay = DateTime.now().difference(lastPlayed).inHours;

    if (hoursSincePlay < 2) {
      return _config.repeatPenalty2h;
    } else if (hoursSincePlay < 24) {
      return _config.repeatPenalty24h;
    } else if (hoursSincePlay < 72) {
      return _config.repeatPenalty3d;
    }
    return 0.0;
  }

  double _calculateSkipPenalty(Track candidate, UserTasteProfile profile) {
    final skips = profile.trackSkipCounts[candidate.id] ?? 0;
    if (skips <= 0) return 0.0;

    // Cautious skip penalty: single skip is minor; multiple skips reduce score
    return (skips * _config.skipPenalty).clamp(0.0, 0.75);
  }

  RecommendationReason _determineExplanationReason({
    required Track candidate,
    required UserTasteProfile profile,
    Track? seedTrack,
    required double prefScore,
    required double simScore,
    required double divScore,
    required List<String> userLanguages,
  }) {
    final lang = _trackLanguageMap[candidate.id];
    if (profile.isColdStart) {
      return RecommendationReason.coldStart(language: lang);
    }

    if (profile.likedTrackIds.contains(candidate.id)) {
      return RecommendationReason.likedTrack(candidate.title);
    }

    // Artist affinity check
    for (final artist in candidate.artists) {
      final name = artist.name.trim();
      final affinity = profile.artistAffinities[name] ?? 0.0;
      if (affinity >= 0.5) {
        return RecommendationReason.artistAffinity(name);
      }
    }

    if (seedTrack != null && simScore >= 0.6) {
      return RecommendationReason.contentSimilarity(seedTrack.title);
    }

    if (divScore >= 0.6 && candidate.artists.isNotEmpty) {
      return RecommendationReason.discoverArtist(candidate.artists.first.name);
    }

    if (lang != null && userLanguages.contains(lang)) {
      return RecommendationReason.languageTrending(lang);
    }

    final topArtist = candidate.artists.isNotEmpty ? candidate.artists.first.name : null;
    return RecommendationReason.recentListening(topArtist);
  }

  Future<List<String>> _getUserMusicLanguages() async {
    try {
      final raw = await _settingsDao.getSettingStr(SettingKeys.musicLanguages);
      if (raw != null && raw.isNotEmpty) {
        return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    } catch (_) {}
    return const ['Hindi', 'English'];
  }
}
