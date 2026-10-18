import 'dart:developer';

import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/screens/widgets/share_to_playlist_sheet.dart';
import 'package:Bloomee/services/share/share_event_deduplicator.dart';
import 'package:Bloomee/services/share/shared_music_models.dart';
import 'package:Bloomee/services/shared_url_resolver_service.dart';
import 'package:Bloomee/utils/url_checker.dart';
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';

typedef YoutubeResolverFn = Future<SharedUrlResolveResult> Function(String url);
typedef SpotifyResolverFn = Future<SharedUrlResolveResult> Function(String url);
typedef SearchTrackFn = Future<Track?> Function(String query);

/// Core service for handling incoming Android share payloads into TarangX.
///
/// Converts untrusted shared text/URLs into identified tracks,
/// enforces privacy, protects against duplicate execution, and
/// launches the playlist addition workflow without touching active playback.
class AndroidShareService {
  final YoutubeResolverFn _youtubeResolver;
  final SpotifyResolverFn _spotifyResolver;
  final SearchTrackFn _searchTrack;

  const AndroidShareService({
    YoutubeResolverFn? youtubeResolver,
    SpotifyResolverFn? spotifyResolver,
    SearchTrackFn? searchTrack,
  })  : _youtubeResolver =
            youtubeResolver ?? SharedUrlResolverService.resolveYoutubeVideo,
        _spotifyResolver =
            spotifyResolver ?? SharedUrlResolverService.resolveSpotifyTrack,
        _searchTrack =
            searchTrack ?? SharedUrlResolverService.searchFirstTrack;

  static const defaultService = AndroidShareService();

  /// Resolve a shared text or URL payload into a [SharedMusicResolution].
  Future<SharedMusicResolution> resolveSharedContent(String? rawContent) async {
    final payload = ExtractedSharePayload.fromText(rawContent);

    if (!payload.isValid) {
      return SharedMusicResolution(
        status: SharedMusicResolutionStatus.failed,
        message: payload.rejectionReason ?? 'Invalid or unsupported content.',
        payload: payload,
      );
    }

    switch (payload.type) {
      case SharedPayloadType.youtubeVideo:
        final url = payload.extractedUrl!;
        try {
          final res = await _youtubeResolver(url);
          if (res.status == SharedUrlResolveStatus.success && res.track != null) {
            return SharedMusicResolution(
              status: SharedMusicResolutionStatus.success,
              track: res.track,
              payload: payload,
              message: 'Track identified from YouTube link.',
            );
          }
        } catch (e) {
          log('YouTube resolution failed: $e', name: 'AndroidShareService');
        }

        final videoId = extractVideoId(url);
        final fallbackQuery = payload.metadataText ?? videoId;
        return SharedMusicResolution(
          status: SharedMusicResolutionStatus.needsSearchFallback,
          suggestedQuery: fallbackQuery,
          payload: payload,
          message:
              'Could not automatically resolve this YouTube link. You can search for the track manually below.',
        );

      case SharedPayloadType.spotifyTrack:
        // If metadata text accompanied the Spotify URL (e.g., "Song Name by Artist Name https://..."),
        // use it directly for fast track search.
        if (payload.metadataText != null &&
            payload.metadataText!.trim().isNotEmpty) {
          try {
            final track = await _searchTrack(payload.metadataText!);
            if (track != null) {
              return SharedMusicResolution(
                status: SharedMusicResolutionStatus.success,
                track: track,
                payload: payload,
                message: 'Track identified from Spotify share.',
              );
            }
          } catch (_) {}
        }

        // Try standard public Spotify oEmbed resolution.
        final url = payload.extractedUrl!;
        try {
          final res = await _spotifyResolver(url);
          if (res.status == SharedUrlResolveStatus.success && res.track != null) {
            return SharedMusicResolution(
              status: SharedMusicResolutionStatus.success,
              track: res.track,
              payload: payload,
              message: 'Track identified from Spotify link.',
            );
          }
        } catch (e) {
          log('Spotify resolution failed: $e', name: 'AndroidShareService');
        }

        return SharedMusicResolution(
          status: SharedMusicResolutionStatus.needsSearchFallback,
          suggestedQuery: payload.metadataText,
          payload: payload,
          message:
              'Could not automatically resolve this Spotify track. You can search for the song below.',
        );

      case SharedPayloadType.instagramReel:
        // Instagram Reel links do not expose public audio streams or unauthenticated audio APIs.
        // As required, clearly inform the user and provide a manual search fallback using any shared metadata.
        return SharedMusicResolution(
          status: SharedMusicResolutionStatus.needsSearchFallback,
          suggestedQuery: payload.metadataText,
          payload: payload,
          message:
              'Instagram Reel links do not provide direct song audio. You can search for the song title manually below to add it to your playlist.',
        );

      case SharedPayloadType.plainText:
        // Plain text title/artist shared by user.
        return SharedMusicResolution(
          status: SharedMusicResolutionStatus.needsSearchFallback,
          suggestedQuery: payload.metadataText,
          payload: payload,
          message:
              'Search for this song to select and add it to your playlist:',
        );

      case SharedPayloadType.otherUrl:
        return SharedMusicResolution(
          status: SharedMusicResolutionStatus.unsupported,
          suggestedQuery: payload.metadataText,
          payload: payload,
          message:
              'This link is not a recognized music provider. You can search for the track manually below:',
        );

      case SharedPayloadType.invalid:
        return SharedMusicResolution(
          status: SharedMusicResolutionStatus.failed,
          message: payload.rejectionReason ?? 'Invalid content.',
          payload: payload,
        );
    }
  }

  /// Entry point called when Android share media is received.
  /// Deduplicates events and presents the ShareToPlaylistSheet.
  static Future<void> handleSharedMedia(
    BuildContext context,
    SharedMedia media, {
    AndroidShareService service = defaultService,
  }) async {
    final content = media.content;
    if (content == null || content.trim().isEmpty) return;

    if (ShareEventDeduplicator.isDuplicate(content)) {
      log('Ignored duplicate Android share event: ${content.substring(0, content.length.clamp(0, 50))}',
          name: 'AndroidShareService');
      return;
    }

    // Reset native initial media immediately so subsequent app resumes do not re-emit.
    try {
      await ShareHandlerPlatform.instance.resetInitialSharedMedia();
    } catch (_) {}

    if (!context.mounted) return;

    await ShareToPlaylistSheet.show(
      context,
      rawContent: content,
      shareService: service,
    );
  }
}
