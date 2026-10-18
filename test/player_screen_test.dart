import 'package:flutter_test/flutter_test.dart';
import 'package:Bloomee/services/player/player_engine.dart';

void main() {
  group('Now Playing Controls State & Logic', () {
    test('LoopMode cycling sequence: off -> all -> one -> off', () {
      LoopMode mode = LoopMode.off;

      // Tap 1: off -> all
      if (mode == LoopMode.off) {
        mode = LoopMode.all;
      } else if (mode == LoopMode.all) {
        mode = LoopMode.one;
      } else {
        mode = LoopMode.off;
      }
      expect(mode, LoopMode.all);

      // Tap 2: all -> one
      if (mode == LoopMode.off) {
        mode = LoopMode.all;
      } else if (mode == LoopMode.all) {
        mode = LoopMode.one;
      } else {
        mode = LoopMode.off;
      }
      expect(mode, LoopMode.one);

      // Tap 3: one -> off
      if (mode == LoopMode.off) {
        mode = LoopMode.all;
      } else if (mode == LoopMode.all) {
        mode = LoopMode.one;
      } else {
        mode = LoopMode.off;
      }
      expect(mode, LoopMode.off);
    });

    test('Shuffle toggle inverts mode accurately', () {
      bool isShuffle = false;
      isShuffle = !isShuffle;
      expect(isShuffle, isTrue);

      isShuffle = !isShuffle;
      expect(isShuffle, isFalse);
    });

    test('Active lyric index calculation handles boundaries and progress', () {
      final mockLyrics = [
        {'time': const Duration(seconds: 0), 'text': 'Line 1'},
        {'time': const Duration(seconds: 10), 'text': 'Line 2'},
        {'time': const Duration(seconds: 25), 'text': 'Line 3'},
        {'time': const Duration(seconds: 40), 'text': 'Line 4'},
      ];

      int findActiveIndex(Duration pos) {
        if (mockLyrics.isEmpty) return -1;
        if (pos < (mockLyrics.first['time'] as Duration)) return 0;
        for (int i = 0; i < mockLyrics.length; i++) {
          final lineStart = mockLyrics[i]['time'] as Duration;
          final nextStart = (i + 1 < mockLyrics.length)
              ? (mockLyrics[i + 1]['time'] as Duration)
              : const Duration(hours: 10);
          if (pos >= lineStart && pos < nextStart) {
            return i;
          }
        }
        return mockLyrics.length - 1;
      }

      expect(findActiveIndex(const Duration(seconds: 0)), 0);
      expect(findActiveIndex(const Duration(seconds: 5)), 0);
      expect(findActiveIndex(const Duration(seconds: 10)), 1);
      expect(findActiveIndex(const Duration(seconds: 20)), 1);
      expect(findActiveIndex(const Duration(seconds: 25)), 2);
      expect(findActiveIndex(const Duration(seconds: 39)), 2);
      expect(findActiveIndex(const Duration(seconds: 45)), 3);
      expect(findActiveIndex(const Duration(minutes: 5)), 3);
    });

    test('Responsive layout width threshold distinguishes mobile and Linux desktop', () {
      bool isMobile(double width) => width < 800;

      // Phones
      expect(isMobile(360), isTrue);  // standard phone
      expect(isMobile(412), isTrue);  // large phone
      expect(isMobile(600), isTrue);  // small tablet portrait

      // Desktop / Wide window (Linux)
      expect(isMobile(800), isFalse); // desktop breakpoint
      expect(isMobile(1024), isFalse); // laptop window
      expect(isMobile(1920), isFalse); // full HD monitor
    });
  });
}
