import 'package:Bloomee/services/tarangx_player.dart';
import 'package:bloc/bloc.dart';
import 'package:rxdart/rxdart.dart';
part 'tarangx_player_state.dart';

class TarangXPlayerCubit extends Cubit<TarangXPlayerState> {
  final TarangXMusicPlayer tarangXPlayer;
  late ValueStream<ProgressBarStreams> progressStreams;

  TarangXPlayerCubit(this.tarangXPlayer)
      : super(TarangXPlayerState(isReady: true)) {
    tarangXPlayer.syncPublicState();
    _setupProgressStreams();
  }

  void switchShowLyrics({bool? value}) {
    emit(TarangXPlayerState(
        isReady: true, showLyrics: value ?? !state.showLyrics));
  }

  void _setupProgressStreams() {
    progressStreams = Rx.combineLatest4(
      Rx.defer(() => tarangXPlayer.engine.positionStream, reusable: true),
      Rx.defer(() => tarangXPlayer.engine.durationStream, reusable: true),
      Rx.defer(() => tarangXPlayer.engine.bufferedStream, reusable: true),
      Rx.defer(() => tarangXPlayer.engine.playingStream, reusable: true),
      (Duration position, Duration duration, Duration buffered, bool playing) =>
          ProgressBarStreams(
        position: position,
        duration: duration,
        buffered: buffered,
        isPlaying: playing,
      ),
    ).shareValueSeeded(
      ProgressBarStreams(
        position: Duration.zero,
        duration: Duration.zero,
        buffered: Duration.zero,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> close() {
    // Intentionally does NOT stop the player.
    // The AudioService foreground service manages its own lifecycle via
    // onTaskRemoved() / onNotificationDeleted().
    return super.close();
  }
}

/// Backward compatibility alias
typedef BloomeePlayerCubit = TarangXPlayerCubit;
