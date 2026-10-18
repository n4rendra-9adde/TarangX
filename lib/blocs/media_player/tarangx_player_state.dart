// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'tarangx_player_cubit.dart';

class TarangXPlayerState {
  bool isReady;
  bool showLyrics;
  TarangXPlayerState({required this.isReady, this.showLyrics = false});
}

final class TarangXPlayerInitial extends TarangXPlayerState {
  TarangXPlayerInitial() : super(isReady: false);
}

/// Backward compatibility aliases
typedef BloomeePlayerState = TarangXPlayerState;
typedef BloomeePlayerInitial = TarangXPlayerInitial;

/// Simplified progress bar data using only [Duration] values,
/// decoupled from any audio library types.
class ProgressBarStreams {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool isPlaying;
  ProgressBarStreams({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.isPlaying,
  });
}
