import 'package:Bloomee/services/tarangx_player.dart';
import 'package:Bloomee/core/theme/app_theme.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

/// Initializes the audio session and player.
///
/// ## Why configure() is called HERE (not in TarangXMusicPlayer's constructor)
///
/// Dart constructors cannot `await`. If AudioSession.configure() is called
/// inside the player constructor (fire-and-forget), there is a race window
/// on slow/cold-start devices where the user taps a song before configure()
/// completes. setActive(true) then calls requestAudioFocus() with unconfigured
/// attributes → AUDIOFOCUS_REQUEST_FAILED on Xiaomi MIUI / Samsung OneUI.
///
/// Calling configure() here, before AudioService.init(), eliminates the race:
/// the session is fully configured before any TarangXMusicPlayer method can run.
Future<void> setupAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration(
    // iOS
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions:
        AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.allowAirPlay,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    avAudioSessionRouteSharingPolicy:
        AVAudioSessionRouteSharingPolicy.defaultPolicy,
    avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    // Android
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    // We handle ducking ourselves via interruptionEventStream.
    androidWillPauseWhenDucked: false,
  ));
}

/// Singleton that creates and owns the [TarangXMusicPlayer] instance.
///
/// Using a [Completer] (not a busy-wait while loop) to serialize concurrent
/// initialization calls. The old pattern with `while (_isInitializing)`
/// polled every 50ms and could theoretically spin indefinitely if init threw
/// an exception that bypassed the `finally` block.
class PlayerInitializer {
  static final PlayerInitializer _instance = PlayerInitializer._internal();
  factory PlayerInitializer() => _instance;
  PlayerInitializer._internal();

  TarangXMusicPlayer? _player;
  // Completer is set during init, removed when done. Any callers that arrive
  // while init is in progress simply await the same future.
  Future<TarangXMusicPlayer>? _initFuture;

  Future<TarangXMusicPlayer> getTarangXMusicPlayer() async {
    // 1. Already initialized and healthy — fast path.
    final p = _player;
    if (p != null) {
      if (!p.isPlayerHealthy) await p.revive();
      return p;
    }

    // 2. Initialization in progress — wait for it.
    final running = _initFuture;
    if (running != null) return running;

    // 3. Start initialization.
    _initFuture = _initializeInternal();
    try {
      return await _initFuture!;
    } finally {
      _initFuture = null;
    }
  }

  Future<TarangXMusicPlayer> _initializeInternal() async {
    final player = await AudioService.init(
      builder: () => TarangXMusicPlayer(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.tarangx.musicplayer.notification.status',
        androidNotificationChannelName: 'TarangX',
        androidNotificationIcon: 'mipmap/ic_launcher',
        androidResumeOnClick: true,
        androidShowNotificationBadge: true,
        // Keep foreground service alive while paused — reduces OEM process kills.
        androidStopForegroundOnPause: false,
        notificationColor: Default_Theme.accentColor2,
      ),
    );
    _player = player;
    return player;
  }
}
