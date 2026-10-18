import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Prevents processing the same Android share event twice.
///
/// Handles cases where `getInitialSharedMedia()` and `sharedMediaStream`
/// both report the same intent, or Android activity re-attaches / configuration changes
/// re-emit the identical share payload.
class ShareEventDeduplicator {
  static final Map<String, DateTime> _seenFingerprints = {};
  static const Duration cooldown = Duration(seconds: 4);

  /// Returns `true` if this payload was already processed recently within [cooldown].
  static bool isDuplicate(String? content) {
    if (content == null || content.trim().isEmpty) return false;
    final normalized = content.trim();
    final fingerprint = sha256.convert(utf8.encode(normalized)).toString();
    final now = DateTime.now();

    // Purge expired records.
    _seenFingerprints.removeWhere((_, timestamp) => now.difference(timestamp) > cooldown);

    final lastSeen = _seenFingerprints[fingerprint];
    if (lastSeen != null && now.difference(lastSeen) < cooldown) {
      return true;
    }

    _seenFingerprints[fingerprint] = now;
    return false;
  }

  /// Reset the deduplicator cache (useful for testing).
  static void reset() {
    _seenFingerprints.clear();
  }
}
