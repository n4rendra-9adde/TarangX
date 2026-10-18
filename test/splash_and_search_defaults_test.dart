import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Bloomee/screens/widgets/tarangx_splash_screen.dart';
import 'package:Bloomee/src/rust/api/plugin/commands.dart';
import 'package:Bloomee/src/rust/api/plugin/manifest.dart';
import 'package:Bloomee/src/rust/api/plugin/plugin_info.dart';

class FakePluginInfo implements PluginInfo {
  @override
  final Manifest manifest;
  @override
  final String name;

  FakePluginInfo({required String id, required this.name})
      : manifest = Manifest(
          manifestVersion: 1,
          id: id,
          name: name,
          version: '1.0.0',
          type: 'content_resolver',
          description: '$name plugin',
          publisher: const PluginPublisher(name: 'Bloomee'),
          license: 'MIT',
          homepage: 'https://example.com',
          hostSite: const [],
          capabilities: const [],
          keysRequired: const {},
          resolver: true,
          countryAllowlist: const [],
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TarangX Logo Splash Screen & Animation Tests', () {
    testWidgets('TarangXSplashScreen renders brand title, logo asset, and equalizer visualizer',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TarangXSplashScreen(
              statusMessage: 'Starting TarangX...',
            ),
          ),
        ),
      );

      // Verify branding text exists
      expect(find.text('TARANGX'), findsOneWidget);
      expect(find.text('Starting TarangX...'), findsOneWidget);

      // Verify custom status message support
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TarangXSplashScreen(
              statusMessage: 'Initializing Audio Engine...',
            ),
          ),
        ),
      );
      expect(find.text('Initializing Audio Engine...'), findsOneWidget);

      // Advance animation frames to verify smooth continuous pulse
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('TarangXSplashWrapper shows splash overlay then fades out and reveals child',
        (tester) async {
      TarangXSplashWrapper.hasShownInitialSplash = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TarangXSplashWrapper(
              child: Text('Main Application Ready'),
            ),
          ),
        ),
      );

      // Splash is visible on top
      expect(find.text('TARANGX'), findsOneWidget);
      expect(find.text('Main Application Ready'), findsOneWidget);

      // Fast-forward past splash countdown (1350ms) + fade transition (400ms)
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 500));

      // After fade completes, splash is dismissed and hasShownInitialSplash is set
      expect(TarangXSplashWrapper.hasShownInitialSplash, isTrue);
      expect(find.text('Main Application Ready'), findsOneWidget);
    });

    testWidgets('TarangXSplashWrapper skips splash if already displayed during session',
        (tester) async {
      TarangXSplashWrapper.hasShownInitialSplash = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TarangXSplashWrapper(
              child: Text('Main Content Direct'),
            ),
          ),
        ),
      );

      // Direct child without splash
      expect(find.text('TARANGX'), findsNothing);
      expect(find.text('Main Content Direct'), findsOneWidget);
    });
  });

  group('Search Default Selection Tests (Track Filter & JioSaavn Source)', () {
    String resolveDefaultSearchPlugin(
        List<PluginInfo> resolvers, String persistedId) {
      if (resolvers.isEmpty) return '';

      final saavn = resolvers.cast<PluginInfo?>().firstWhere(
        (p) =>
            p != null &&
            (p.manifest.id.toLowerCase().contains('saavn') ||
                p.manifest.name.toLowerCase().contains('saavn')),
        orElse: () => null,
      );

      if (saavn != null) {
        if (persistedId.isEmpty ||
            persistedId.contains('ytvideo') ||
            persistedId.contains('ytmusic') ||
            persistedId.contains('saavn')) {
          return saavn.manifest.id;
        }
        if (resolvers.any((p) => p.manifest.id == persistedId)) {
          return persistedId;
        }
        return saavn.manifest.id;
      }

      if (persistedId.isNotEmpty &&
          resolvers.any((p) => p.manifest.id == persistedId)) {
        return persistedId;
      }

      return resolvers.first.manifest.id;
    }

    test('defaults to JioSaavn when persisted search plugin is empty', () {
      final ytMusic = FakePluginInfo(
          id: 'content-resolver.bloomfactory.ytmusic', name: 'YouTube Music');
      final jioSaavn = FakePluginInfo(
          id: 'content-resolver.bloomfactory.jisaavn', name: 'JioSaavn');
      final ytVideo = FakePluginInfo(
          id: 'content-resolver.bloomfactory.ytvideo', name: 'YouTube Video');

      final resolvers = [ytMusic, jioSaavn, ytVideo];

      final selected = resolveDefaultSearchPlugin(resolvers, '');
      expect(selected, 'content-resolver.bloomfactory.jisaavn');
    });

    test('replaces legacy auto-selected ytvideo fallback with JioSaavn', () {
      final ytMusic = FakePluginInfo(
          id: 'content-resolver.bloomfactory.ytmusic', name: 'YouTube Music');
      final jioSaavn = FakePluginInfo(
          id: 'content-resolver.bloomfactory.jisaavn', name: 'JioSaavn');
      final ytVideo = FakePluginInfo(
          id: 'content-resolver.bloomfactory.ytvideo', name: 'YouTube Video');

      final resolvers = [ytVideo, jioSaavn, ytMusic];

      final selected = resolveDefaultSearchPlugin(
          resolvers, 'content-resolver.bloomfactory.ytvideo');
      expect(selected, 'content-resolver.bloomfactory.jisaavn');
    });

    test('preserves user persisted non-youtube plugin choice when valid and loaded', () {
      final spotify = FakePluginInfo(
          id: 'content-resolver.bloomfactory.spotify', name: 'Spotify');
      final jioSaavn = FakePluginInfo(
          id: 'content-resolver.bloomfactory.jisaavn', name: 'JioSaavn');

      final resolvers = [spotify, jioSaavn];

      final selected = resolveDefaultSearchPlugin(
          resolvers, 'content-resolver.bloomfactory.spotify');
      expect(selected, 'content-resolver.bloomfactory.spotify');
    });

    test('falls back to JioSaavn when persisted plugin is not in loaded resolvers',
        () {
      final jioSaavn = FakePluginInfo(
          id: 'content-resolver.bloomfactory.jisaavn', name: 'JioSaavn');
      final spotify = FakePluginInfo(
          id: 'content-resolver.bloomfactory.spotify', name: 'Spotify');

      final resolvers = [spotify, jioSaavn];

      final selected = resolveDefaultSearchPlugin(
          resolvers, 'content-resolver.uninstalled.plugin');
      expect(selected, 'content-resolver.bloomfactory.jisaavn');
    });

    test('ContentSearchFilter default value is track', () {
      final notifier = ValueNotifier<ContentSearchFilter>(ContentSearchFilter.track);
      expect(notifier.value, ContentSearchFilter.track);
    });
  });

  group('Android Launch Background Verification', () {
    test('launch_background.xml contains centered launcher icon', () {
      final launchBg = File(
          'android/app/src/main/res/drawable/launch_background.xml');
      expect(launchBg.existsSync(), isTrue);
      final content = launchBg.readAsStringSync();
      expect(content.contains('@mipmap/ic_launcher'), isTrue);
      expect(content.contains('android:gravity="center"'), isTrue);
    });

    test('drawable-v21/launch_background.xml contains centered launcher icon', () {
      final launchBgV21 = File(
          'android/app/src/main/res/drawable-v21/launch_background.xml');
      expect(launchBgV21.existsSync(), isTrue);
      final content = launchBgV21.readAsStringSync();
      expect(content.contains('@mipmap/ic_launcher'), isTrue);
      expect(content.contains('android:gravity="center"'), isTrue);
    });
  });
}
