import 'package:Bloomee/src/rust/api/plugin/models.dart';

enum SharedPayloadType {
  youtubeVideo,
  spotifyTrack,
  instagramReel,
  otherUrl,
  plainText,
  invalid,
}

enum SharedMusicResolutionStatus {
  success,
  needsSearchFallback,
  unsupported,
  failed,
  cancelled,
}

class ExtractedSharePayload {
  final String rawText;
  final String? extractedUrl;
  final String? metadataText;
  final SharedPayloadType type;
  final bool isValid;
  final String? rejectionReason;

  const ExtractedSharePayload({
    required this.rawText,
    this.extractedUrl,
    this.metadataText,
    required this.type,
    required this.isValid,
    this.rejectionReason,
  });

  static const int maxInputLength = 8192;

  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  );

  static final RegExp _unsafeSchemeRegex = RegExp(
    r'^(?:javascript|file|content|intent|data|blob|about):',
    caseSensitive: false,
  );

  /// Safely parse and sanitize incoming shared text.
  factory ExtractedSharePayload.fromText(String? input) {
    if (input == null || input.trim().isEmpty) {
      return const ExtractedSharePayload(
        rawText: '',
        type: SharedPayloadType.invalid,
        isValid: false,
        rejectionReason: 'Empty or missing content.',
      );
    }

    if (input.length > maxInputLength) {
      return ExtractedSharePayload(
        rawText: input.substring(0, maxInputLength),
        type: SharedPayloadType.invalid,
        isValid: false,
        rejectionReason: 'Shared content exceeds maximum length (8 KB).',
      );
    }

    final trimmed = input.trim();

    // Check for explicit unsafe schemes in the text.
    if (_unsafeSchemeRegex.hasMatch(trimmed)) {
      return ExtractedSharePayload(
        rawText: trimmed,
        type: SharedPayloadType.invalid,
        isValid: false,
        rejectionReason: 'Unsafe URL scheme rejected.',
      );
    }

    // Attempt to extract an http/https URL.
    final match = _urlRegex.firstMatch(trimmed);
    if (match != null) {
      var rawUrl = match.group(0)!;
      // Strip trailing punctuation commonly appended in sentences or social posts.
      rawUrl = rawUrl.replaceAll(RegExp(r'[\.,;:!\?\)>\]"]+$'), '');

      final parsedUri = Uri.tryParse(rawUrl);
      if (parsedUri == null ||
          !parsedUri.hasScheme ||
          (parsedUri.scheme != 'http' && parsedUri.scheme != 'https') ||
          parsedUri.host.isEmpty) {
        return ExtractedSharePayload(
          rawText: trimmed,
          type: SharedPayloadType.invalid,
          isValid: false,
          rejectionReason: 'Malformed or invalid URL.',
        );
      }

      // Extract accompanying metadata text by removing the URL from the shared text.
      var meta = trimmed.replaceFirst(rawUrl, '').trim();
      // Remove multiline clutter or common social share noise.
      meta = meta.replaceAll(RegExp(r'\s+'), ' ').trim();
      // Strip common boilerplate wrappers.
      meta = meta
          .replaceFirst(RegExp(r'^(?:check out|listen to|watch this reel by|watch this reel|watch video)\s*:?\s*', caseSensitive: false), '')
          .trim();
      final metadata = meta.isNotEmpty ? meta : null;

      final host = parsedUri.host.toLowerCase();
      final SharedPayloadType payloadType;

      if (host.contains('youtube.com') || host.contains('music.youtube.com') || host == 'youtu.be') {
        payloadType = SharedPayloadType.youtubeVideo;
      } else if (host == 'open.spotify.com' && parsedUri.pathSegments.contains('track')) {
        payloadType = SharedPayloadType.spotifyTrack;
      } else if (host.contains('instagram.com')) {
        payloadType = SharedPayloadType.instagramReel;
      } else {
        payloadType = SharedPayloadType.otherUrl;
      }

      return ExtractedSharePayload(
        rawText: trimmed,
        extractedUrl: rawUrl,
        metadataText: metadata,
        type: payloadType,
        isValid: true,
      );
    }

    // No URL found: treat as plain text title/artist query.
    return ExtractedSharePayload(
      rawText: trimmed,
      metadataText: trimmed,
      type: SharedPayloadType.plainText,
      isValid: true,
    );
  }
}

class SharedMusicResolution {
  final SharedMusicResolutionStatus status;
  final Track? track;
  final String? suggestedQuery;
  final String message;
  final ExtractedSharePayload payload;

  const SharedMusicResolution({
    required this.status,
    this.track,
    this.suggestedQuery,
    required this.message,
    required this.payload,
  });

  bool get isSuccess => status == SharedMusicResolutionStatus.success && track != null;
}
