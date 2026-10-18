import 'dart:developer';

bool isUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  } catch (e) {
    return false;
  }
}

enum UrlType {
  youtubeVideo,
  youtubePlaylist,
  spotifyTrack,
  spotifyPlaylist,
  spotifyAlbum,
  other,
}

String? extractVideoId(String url) {
  try {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host.contains('youtube.com') || host.contains('music.youtube.com')) {
      if (uri.queryParameters.containsKey('v')) {
        final v = uri.queryParameters['v'];
        if (v != null && v.isNotEmpty) return v;
      }
      final segments = uri.pathSegments;
      final shortsIdx = segments.indexOf('shorts');
      if (shortsIdx != -1 && shortsIdx + 1 < segments.length) {
        return segments[shortsIdx + 1];
      }
      final embedIdx = segments.indexOf('embed');
      if (embedIdx != -1 && embedIdx + 1 < segments.length) {
        return segments[embedIdx + 1];
      }
      final vIdx = segments.indexOf('v');
      if (vIdx != -1 && vIdx + 1 < segments.length) {
        return segments[vIdx + 1];
      }
    }
    if (host == 'youtu.be') {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
  } catch (e) {
    log(e.toString(), name: 'extractVideoId');
  }
  return null;
}

UrlType getUrlType(String url) {
  if (!isUrl(url)) return UrlType.other;
  try {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();

    // YouTube
    if (host.contains('youtube.com') || host.contains('youtu.be') ||
        host.contains('music.youtube.com')) {
      return uri.queryParameters.containsKey('list')
          ? UrlType.youtubePlaylist
          : UrlType.youtubeVideo;
    }

    // Spotify
    if (host == 'open.spotify.com' && uri.pathSegments.length >= 2) {
      return switch (uri.pathSegments[0]) {
        'track' => UrlType.spotifyTrack,
        'playlist' => UrlType.spotifyPlaylist,
        'album' => UrlType.spotifyAlbum,
        _ => UrlType.other,
      };
    }
  } catch (_) {}
  return UrlType.other;
}
