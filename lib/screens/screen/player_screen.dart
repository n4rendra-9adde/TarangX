import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:Bloomee/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Bloomee/blocs/library/cubit/library_items_cubit.dart';
import 'package:Bloomee/blocs/lyrics/lyrics_cubit.dart';
import 'package:Bloomee/blocs/media_player/tarangx_player_cubit.dart';
import 'package:Bloomee/blocs/mini_player/mini_player_cubit.dart';
import 'package:Bloomee/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:Bloomee/core/adapters/track_adapter.dart';
import 'package:Bloomee/core/models/lyrics_models.dart';
import 'package:Bloomee/core/theme/app_theme.dart';
import 'package:Bloomee/l10n/app_localizations.dart';
import 'package:Bloomee/screens/screen/home_views/setting_views/player_setting.dart';
import 'package:Bloomee/screens/screen/home_views/timer_view.dart';
import 'package:Bloomee/screens/screen/player_views/equalizer_view.dart';
import 'package:Bloomee/screens/screen/player_views/fullscreen_lyrics_view.dart';
import 'package:Bloomee/screens/screen/player_views/lyrics_search.dart';
import 'package:Bloomee/screens/screen/player_views/segments_sheet.dart';
import 'package:Bloomee/screens/widgets/gradient_progress_bar.dart';
import 'package:Bloomee/screens/widgets/media_metadata_links.dart';
import 'package:Bloomee/screens/widgets/more_bottom_sheet.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/screens/widgets/up_next_panel.dart';
import 'package:Bloomee/screens/widgets/volume_slider.dart';
import 'package:Bloomee/services/player/player_engine.dart';
import 'package:Bloomee/services/tarangx_player.dart';
import 'package:Bloomee/utils/load_image.dart';
import 'package:Bloomee/utils/pallete_generator.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

enum _CenterDisplayMode {
  artwork,
  lyrics,
}

/// The premium TarangX Now Playing screen.
///
/// Implements a dark-luxury aesthetic with ambient background lighting,
/// large album artwork with volume gestures, inline synchronized lyrics with
/// tap-to-seek, universal playback controls row, and responsive two-column
/// layout for Linux desktop.
class AudioPlayerView extends StatefulWidget {
  const AudioPlayerView({super.key});

  @override
  State<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends State<AudioPlayerView> {
  final UpNextPanelController _upNextPanelController = UpNextPanelController();
  _CenterDisplayMode _currentCenterMode = _CenterDisplayMode.artwork;
  int _desktopRightTabIndex = 0; // 0: Queue, 1: Lyrics

  Color? _cachedPaletteColor;
  String? _lastArtUri;
  StreamSubscription? _paletteSub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PlayerOverlayCubit>().registerUpNextPanelCollapse(
              () => _upNextPanelController.collapse(),
            );
      }
    });

    final player = context.read<TarangXPlayerCubit>().tarangXPlayer;
    _paletteSub = player.mediaItem.listen((mi) {
      final artUri = mi?.artUri?.toString();
      if (artUri != _lastArtUri) {
        _lastArtUri = artUri;
        _extractPalette(artUri);
      }
    });

    final current = player.mediaItem.valueOrNull;
    _lastArtUri = current?.artUri?.toString();
    _extractPalette(_lastArtUri);
  }

  Future<void> _extractPalette(String? artUri) async {
    if (artUri == null || artUri.isEmpty) return;
    try {
      final palette = await getPalleteFromImage(artUri);
      if (mounted) {
        setState(() {
          _cachedPaletteColor = palette.dominantColor?.color;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    context.read<PlayerOverlayCubit>().unregisterUpNextPanelCollapse();
    _paletteSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerCubit = context.read<TarangXPlayerCubit>();
    final musicPlayer = playerCubit.tarangXPlayer;
    final isMobile = ResponsiveBreakpoints.of(context).smallerOrEqualTo(TABLET);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 1. Collapse Up Next panel if expanded
        if (_upNextPanelController.collapse()) return;
        // 2. Return to artwork mode if lyrics mode is active
        if (_currentCenterMode != _CenterDisplayMode.artwork) {
          setState(() => _currentCenterMode = _CenterDisplayMode.artwork);
          return;
        }
        // 3. Hide player overlay back to mini player
        context.read<PlayerOverlayCubit>().hidePlayer();
      },
      child: Scaffold(
        backgroundColor: Default_Theme.themeColor,
        resizeToAvoidBottomInset: false,
        body: isMobile
            ? _buildMobileLayout(context, musicPlayer)
            : _buildDesktopLayout(context, musicPlayer),
      ),
    );
  }

  // ── Mobile Phone & Tablet Layout (Android) ──────────────────────────────────
  Widget _buildMobileLayout(
    BuildContext context,
    TarangXMusicPlayer musicPlayer,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        // Dynamically compute artwork dimensions to guarantee zero overflow
        final double artSize = math.min(
          constraints.maxWidth * 0.82,
          (availableHeight - 330).clamp(180.0, 350.0),
        );

        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Ambient colored background layer
            Positioned.fill(
              child: _AmbientBackgroundLayer(artColor: _cachedPaletteColor),
            ),

            // Main Player Body
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Top App Header
                    _buildTopBarMobile(context, musicPlayer),

                    // Center Interactive Hero (Artwork or Synced Lyrics)
                    Expanded(
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _currentCenterMode == _CenterDisplayMode.artwork
                              ? _AlbumArtworkCard(
                                  key: const ValueKey('artwork_mode'),
                                  musicPlayer: musicPlayer,
                                  dominantColor: _cachedPaletteColor,
                                  maxSize: artSize,
                                )
                              : _InlineLyricsView(
                                  key: const ValueKey('lyrics_mode'),
                                  musicPlayer: musicPlayer,
                                  isDesktop: false,
                                  onSwitchToArtwork: () {
                                    setState(() {
                                      _currentCenterMode =
                                          _CenterDisplayMode.artwork;
                                    });
                                  },
                                ),
                        ),
                      ),
                    ),

                    // Bottom Controls Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _SongInfoRow(),
                          const SizedBox(height: 10),
                          const _PlayerProgressBar(),
                          const SizedBox(height: 14),
                          _PlayerControlsRow(musicPlayer: musicPlayer),
                          const SizedBox(height: 10),
                          _buildSecondaryUtilityBar(context, musicPlayer),
                          const SizedBox(height: 56), // UpNext peek space
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Draggable UpNext bottom sheet
            UpNextPanel(
              peekHeight: 52.0,
              parentHeight: availableHeight,
              controller: _upNextPanelController,
            ),
          ],
        );
      },
    );
  }

  // ── Desktop / Large Screen Layout (Linux) ──────────────────────────────────
  Widget _buildDesktopLayout(
    BuildContext context,
    TarangXMusicPlayer musicPlayer,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: _AmbientBackgroundLayer(artColor: _cachedPaletteColor),
        ),
        SafeArea(
          child: Row(
            children: [
              // Left Column: Player Hero & Controls
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 380,
                  maxWidth: math.max(
                    380.0,
                    MediaQuery.of(context).size.width * 0.46,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 20, 24),
                  child: Column(
                    children: [
                      _buildTopBarDesktop(context, musicPlayer),
                      const Spacer(),
                      _AlbumArtworkCard(
                        musicPlayer: musicPlayer,
                        dominantColor: _cachedPaletteColor,
                        maxSize: 340,
                      ),
                      const Spacer(),
                      const _SongInfoRow(),
                      const SizedBox(height: 14),
                      const _PlayerProgressBar(),
                      const SizedBox(height: 16),
                      _PlayerControlsRow(musicPlayer: musicPlayer),
                      const SizedBox(height: 10),
                      _buildSecondaryUtilityBar(context, musicPlayer),
                    ],
                  ),
                ),
              ),

              // Vertical Glass Divider
              Container(
                width: 0.8,
                margin: const EdgeInsets.symmetric(vertical: 24),
                color: Colors.white.withValues(alpha: 0.08),
              ),

              // Right Column: Side-by-side Up Next Queue & Synced Lyrics
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 28, 24),
                  child: _buildDesktopRightPanel(context, musicPlayer),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Desktop Right Column: Tabbed Queue & Lyrics ────────────────────────────
  Widget _buildDesktopRightPanel(
    BuildContext context,
    TarangXMusicPlayer musicPlayer,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              // Segmented Tab Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  children: [
                    _buildDesktopTabPill(
                      label: 'Up Next Queue',
                      icon: MingCute.playlist_fill,
                      isSelected: _desktopRightTabIndex == 0,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _desktopRightTabIndex = 0);
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildDesktopTabPill(
                      label: 'Synced Lyrics',
                      icon: MingCute.align_center_line,
                      isSelected: _desktopRightTabIndex == 1,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _desktopRightTabIndex = 1);
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      iconSize: 20,
                      tooltip: 'Equalizer',
                      icon: const Icon(
                        Icons.equalizer_rounded,
                        color: Default_Theme.primaryColor2,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EqualizerView(),
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 20,
                      tooltip: 'Settings',
                      icon: const Icon(
                        MingCute.settings_6_line,
                        color: Default_Theme.primaryColor2,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PlayerSettings(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x14FFFFFF)),

              // Tab View Content
              Expanded(
                child: _desktopRightTabIndex == 0
                    ? UpNextPanel(
                        peekHeight: 60,
                        parentHeight:
                            MediaQuery.of(context).size.height * 0.85,
                        isDesktopMode: true,
                      )
                    : _InlineLyricsView(
                        musicPlayer: musicPlayer,
                        isDesktop: true,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTabPill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected ? Default_Theme.brandGradient : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Default_Theme.primaryColor2,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Default_Theme.primaryColor2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Navigation Bars ─────────────────────────────────────────────────────
  Widget _buildTopBarMobile(
    BuildContext context,
    TarangXMusicPlayer musicPlayer,
  ) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            color: Default_Theme.primaryColor1,
            onPressed: () {
              if (!_upNextPanelController.collapse()) {
                if (_currentCenterMode != _CenterDisplayMode.artwork) {
                  setState(
                    () => _currentCenterMode = _CenterDisplayMode.artwork,
                  );
                } else {
                  context.read<PlayerOverlayCubit>().hidePlayer();
                }
              }
            },
          ),
          const Spacer(),
          // Center: Mode pill toggle (Music | Lyrics)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCenterModePill(
                  label: 'Music',
                  isSelected: _currentCenterMode == _CenterDisplayMode.artwork,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _currentCenterMode = _CenterDisplayMode.artwork,
                    );
                  },
                ),
                _buildCenterModePill(
                  label: 'Lyrics',
                  isSelected: _currentCenterMode == _CenterDisplayMode.lyrics,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(
                      () => _currentCenterMode = _CenterDisplayMode.lyrics,
                    );
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            iconSize: 20,
            tooltip: 'Segments',
            icon: const Icon(
              MingCute.list_check_3_line,
              color: Default_Theme.primaryColor1,
            ),
            onPressed: () {
              final mi = musicPlayer.mediaItem.valueOrNull;
              if (mi != null) {
                showSegmentsSheet(
                  context,
                  trackId: mi.id,
                  trackDuration: mi.duration ?? Duration.zero,
                  onSeek: (pos) => musicPlayer.seek(pos),
                );
              }
            },
          ),
          IconButton(
            iconSize: 21,
            tooltip: 'Equalizer',
            icon: const Icon(
              Icons.equalizer_rounded,
              color: Default_Theme.primaryColor1,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EqualizerView()),
              );
            },
          ),
          IconButton(
            iconSize: 22,
            tooltip: 'More',
            icon: const Icon(
              MingCute.more_2_fill,
              color: Default_Theme.primaryColor1,
            ),
            onPressed: () =>
                showMoreBottomSheet(context, musicPlayer.currentMedia),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarDesktop(
    BuildContext context,
    TarangXMusicPlayer musicPlayer,
  ) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          color: Default_Theme.primaryColor1,
          onPressed: () {
            context.read<PlayerOverlayCubit>().hidePlayer();
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PLAYING FROM',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Default_Theme.accentLavender.withValues(alpha: 0.8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 1),
              StreamBuilder<String>(
                stream: musicPlayer.queueTitle,
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 'TarangX Queue',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Default_Theme.primaryColor1,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        IconButton(
          iconSize: 20,
          tooltip: 'Sleep Timer',
          icon: const Icon(
            MingCute.alarm_1_line,
            color: Default_Theme.primaryColor1,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TimerView()),
            );
          },
        ),
        IconButton(
          iconSize: 22,
          tooltip: 'More options',
          icon: const Icon(
            MingCute.more_2_fill,
            color: Default_Theme.primaryColor1,
          ),
          onPressed: () =>
              showMoreBottomSheet(context, musicPlayer.currentMedia),
        ),
      ],
    );
  }

  Widget _buildCenterModePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
        decoration: BoxDecoration(
          gradient: isSelected ? Default_Theme.brandGradient : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Default_Theme.primaryColor2,
          ),
        ),
      ),
    );
  }

  // ── Secondary Action Bar (Quick Access) ───────────────────────────────────
  Widget _buildSecondaryUtilityBar(
    BuildContext context,
    TarangXMusicPlayer musicPlayer,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _UtilityBarButton(
            icon: _currentCenterMode == _CenterDisplayMode.lyrics
                ? MingCute.disc_line
                : MingCute.align_center_line,
            label: _currentCenterMode == _CenterDisplayMode.lyrics
                ? 'Artwork'
                : 'Lyrics',
            isActive: _currentCenterMode == _CenterDisplayMode.lyrics,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _currentCenterMode =
                    _currentCenterMode == _CenterDisplayMode.lyrics
                        ? _CenterDisplayMode.artwork
                        : _CenterDisplayMode.lyrics;
              });
            },
          ),
          _UtilityBarButton(
            icon: Icons.equalizer_rounded,
            label: 'Equalizer',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EqualizerView()),
              );
            },
          ),
          _UtilityBarButton(
            icon: MingCute.playlist_fill,
            label: 'Queue',
            onTap: () {
              HapticFeedback.lightImpact();
              _upNextPanelController.toggle();
            },
          ),
          _UtilityBarButton(
            icon: MingCute.alarm_1_line,
            label: 'Timer',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TimerView()),
              );
            },
          ),
          _UtilityBarButton(
            icon: MingCute.more_2_fill,
            label: 'More',
            onTap: () {
              HapticFeedback.lightImpact();
              showMoreBottomSheet(context, musicPlayer.currentMedia);
            },
          ),
        ],
      ),
    );
  }
}

// ── Utility Button Component ──────────────────────────────────────────────────
class _UtilityBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _UtilityBarButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? Default_Theme.accentColor2.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? Default_Theme.accentColor2.withValues(alpha: 0.45)
                    : Colors.transparent,
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive
                  ? Default_Theme.accentLavender
                  : Default_Theme.primaryColor2.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Ambient Lighting Background Layer ─────────────────────────────────────────
class _AmbientBackgroundLayer extends StatelessWidget {
  final Color? artColor;

  const _AmbientBackgroundLayer({required this.artColor});

  @override
  Widget build(BuildContext context) {
    final glowColor = artColor ?? Default_Theme.accentColor2;

    return RepaintBoundary(
      child: Stack(
        children: [
          // Base solid dark obsidian
          Container(color: Default_Theme.themeColor),

          // Dynamic radial color glow centered behind album artwork
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.42),
                radius: 0.95,
                colors: [
                  glowColor.withValues(alpha: 0.38),
                  glowColor.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Vertical vignette to ensure 100% WCAG contrast and readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.20),
                  Colors.black.withValues(alpha: 0.60),
                  Default_Theme.themeColor.withValues(alpha: 0.96),
                ],
                stops: const [0.0, 0.60, 0.95],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Album Artwork Card with Ambient Shadow & Volume Drag ──────────────────────
class _AlbumArtworkCard extends StatelessWidget {
  final TarangXMusicPlayer musicPlayer;
  final Color? dominantColor;
  final double maxSize;

  const _AlbumArtworkCard({
    super.key,
    required this.musicPlayer,
    this.dominantColor,
    this.maxSize = 340,
  });

  @override
  Widget build(BuildContext context) {
    return VolumeDragController(
      child: StreamBuilder<MediaItem?>(
        stream: musicPlayer.mediaItem,
        builder: (context, snapshot) {
          final currentTrack = musicPlayer.currentTrackInfo;
          final highResUrl =
              currentTrack.thumbnail.urlHigh ?? currentTrack.thumbnail.url;
          final lowResUrl =
              currentTrack.thumbnail.urlLow ?? currentTrack.thumbnail.url;
          final hasArtwork = highResUrl.isNotEmpty || lowResUrl.isNotEmpty;
          final glowColor = dominantColor ?? Default_Theme.accentColor2;

          return SizedBox(
            width: maxSize,
            height: maxSize,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.32),
                        blurRadius: 32,
                        spreadRadius: 2,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: hasArtwork
                        ? LoadImageCached(
                            imageUrl: highResUrl,
                            fallbackUrl: lowResUrl,
                            fit: BoxFit.cover,
                          )
                        : _VinylArtworkPlaceholder(size: maxSize),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Luxury Vinyl Artwork Fallback ─────────────────────────────────────────────
class _VinylArtworkPlaceholder extends StatelessWidget {
  final double size;

  const _VinylArtworkPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF13131A),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1.2,
              ),
            ),
          ),
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1.2,
              ),
            ),
          ),
          Container(
            width: size * 0.34,
            height: size * 0.34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: Default_Theme.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: Default_Theme.accentGlow,
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                MingCute.music_2_fill,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline Synchronized Lyrics View ───────────────────────────────────────────
class _InlineLyricsView extends StatefulWidget {
  final TarangXMusicPlayer musicPlayer;
  final bool isDesktop;
  final VoidCallback? onSwitchToArtwork;

  const _InlineLyricsView({
    super.key,
    required this.musicPlayer,
    this.isDesktop = false,
    this.onSwitchToArtwork,
  });

  @override
  State<_InlineLyricsView> createState() => _InlineLyricsViewState();
}

class _InlineLyricsViewState extends State<_InlineLyricsView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  StreamSubscription? _posSub;
  int _activeLyricIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollTimer;

  @override
  void initState() {
    super.initState();
    _posSub = widget.musicPlayer.engine.positionStream.listen((pos) {
      _updateActiveLyric(pos);
    });
  }

  void _updateActiveLyric(Duration pos) {
    final lyricsState = context.read<LyricsCubit>().state;
    if (lyricsState is! LyricsLoaded) return;
    final parsed = lyricsState.lyrics.parsedLyrics;
    if (parsed == null || parsed.lyrics.isEmpty) return;

    final lines = parsed.lyrics;
    int targetIdx = -1;

    for (int i = 0; i < lines.length; i++) {
      final lineStart = lines[i].start;
      final nextStart = (i + 1 < lines.length)
          ? lines[i + 1].start
          : const Duration(hours: 10);
      if (pos >= lineStart && pos < nextStart) {
        targetIdx = i;
        break;
      }
    }

    if (targetIdx != -1 && targetIdx != _activeLyricIndex) {
      if (mounted) {
        setState(() => _activeLyricIndex = targetIdx);
        if (!_userIsScrolling && _itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: targetIdx,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: 0.42,
          );
        }
      }
    }
  }

  void _onUserScrolled() {
    _userIsScrolling = true;
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _userIsScrolling = false;
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _userScrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LyricsCubit, LyricsState>(
      builder: (context, state) {
        if (state is LyricsLoading) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Default_Theme.accentLavender,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Fetching synchronized lyrics...',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 13.5,
                    color: Default_Theme.primaryColor2,
                  ),
                ),
              ],
            ),
          );
        }

        if (state is LyricsLoaded) {
          final parsed = state.lyrics.parsedLyrics;
          if (parsed != null && parsed.lyrics.isNotEmpty) {
            return _buildSyncedList(state, parsed.lyrics);
          } else if (state.lyrics.lyricsPlain.isNotEmpty) {
            return _buildPlainLyrics(state.lyrics.lyricsPlain);
          }
        }

        // Empty state when lyrics are unavailable
        return _buildEmptyState(state);
      },
    );
  }

  Widget _buildSyncedList(LyricsLoaded state, List<ParsedLyric> lines) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification) {
              _onUserScrolled();
            }
            return false;
          },
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.12, 0.88, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: ScrollablePositionedList.builder(
              itemCount: lines.length,
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              itemBuilder: (context, index) {
                final line = lines[index];
                final isCurrent = index == _activeLyricIndex;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.musicPlayer.seek(line.start);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: Text(
                      line.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: isCurrent ? 20.5 : 16.5,
                        fontWeight:
                            isCurrent ? FontWeight.w800 : FontWeight.w500,
                        color: isCurrent
                            ? Colors.white
                            : Default_Theme.primaryColor2
                                .withValues(alpha: 0.45),
                        shadows: isCurrent
                            ? [
                                Shadow(
                                  color: Default_Theme.accentLavender
                                      .withValues(alpha: 0.65),
                                  blurRadius: 14,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Corner Overlay Controls (Fullscreen Karaoke & Artwork Switch)
        Positioned(
          top: 8,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Full screen lyrics',
                child: IconButton(
                  iconSize: 20,
                  icon: const Icon(
                    MingCute.fullscreen_line,
                    color: Default_Theme.primaryColor2,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                            const FullscreenLyricsView(),
                        transitionsBuilder: (_, a, __, c) =>
                            FadeTransition(opacity: a, child: c),
                        transitionDuration:
                            const Duration(milliseconds: 280),
                      ),
                    );
                  },
                ),
              ),
              if (!widget.isDesktop && widget.onSwitchToArtwork != null)
                Tooltip(
                  message: 'Return to artwork',
                  child: IconButton(
                    iconSize: 20,
                    icon: const Icon(
                      MingCute.disc_line,
                      color: Default_Theme.primaryColor2,
                    ),
                    onPressed: widget.onSwitchToArtwork,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlainLyrics(String text) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.12, 0.88, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 70),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: widget.isDesktop ? 18.5 : 16.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.85,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(LyricsState state) {
    final l10n = AppLocalizations.of(context)!;
    final track = state.track;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MingCute.music_2_line,
              size: 40,
              color: Default_Theme.primaryColor2.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Lyrics Available',
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Default_Theme.primaryColor1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lyrics are not available for this song yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontSize: 12.5,
                color: Default_Theme.primaryColor2.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Default_Theme.surface.withValues(alpha: 0.8),
                foregroundColor: Default_Theme.accentLavender,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(
                    color: Default_Theme.surfaceBorderSubtle,
                    width: 0.8,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
              ),
              icon: const Icon(MingCute.search_2_line, size: 16),
              label: const Text(
                'Search Online',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: LyricsSearchDelegate(
                    mediaID: track.id,
                    searchFieldLabelText: l10n.lyricsSearchFieldLabel,
                  ),
                  query: buildLyricsSearchSeedQuery(
                    title: track.title,
                    artists: track.artists.map((a) => a.name).toList(),
                    album: track.album?.title,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Song Info, Artist & Favorite Row ──────────────────────────────────────────
class _SongInfoRow extends StatelessWidget {
  const _SongInfoRow();

  @override
  Widget build(BuildContext context) {
    final player = context.read<TarangXPlayerCubit>().tarangXPlayer;

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<MediaItem?>(
            stream: player.mediaItem,
            builder: (context, snapshot) {
              final currentTrack = player.currentTrackInfo;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentTrack.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Default_Theme.primaryColor1,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  TrackMetadataLinks(
                    track: currentTrack,
                    showAlbum: currentTrack.album != null,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Default_Theme.primaryColor2.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        const _DownloadButton(),
        const _LikeButton(),
      ],
    );
  }
}

// ── Download Indicator Button ─────────────────────────────────────────────────
class _DownloadButton extends StatefulWidget {
  const _DownloadButton();

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  String? _lastTrackId;
  bool _isDownloaded = false;
  StreamSubscription? _mediaSub;

  @override
  void initState() {
    super.initState();
    final player = context.read<TarangXPlayerCubit>().tarangXPlayer;
    _mediaSub = player.mediaItem.listen((mi) {
      if (mi?.id != _lastTrackId) {
        _lastTrackId = mi?.id;
        _queryDownloadState(mi);
      }
    });
    _queryDownloadState(player.mediaItem.valueOrNull);
  }

  Future<void> _queryDownloadState(MediaItem? mi) async {
    if (mi == null) {
      if (mounted) setState(() => _isDownloaded = false);
      return;
    }
    try {
      final info = await context
          .read<DownloaderCubit>()
          .getDownloadInfo(mediaItemToTrack(mi));
      if (mounted) setState(() => _isDownloaded = info != null);
    } catch (_) {
      if (mounted) setState(() => _isDownloaded = false);
    }
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDownloaded) return const SizedBox.shrink();

    return Tooltip(
      message: AppLocalizations.of(context)!.tooltipAvailableOffline,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(
          Icons.offline_pin_rounded,
          size: 22,
          color: Default_Theme.accentLavender.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

// ── Favorite / Like Button with Haptic Feedback ───────────────────────────────
class _LikeButton extends StatefulWidget {
  const _LikeButton();

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  String? _lastTrackId;
  bool _isLiked = false;
  StreamSubscription? _mediaSub;

  @override
  void initState() {
    super.initState();
    final player = context.read<TarangXPlayerCubit>().tarangXPlayer;
    _mediaSub = player.mediaItem.listen((mi) {
      if (mi?.id != _lastTrackId) {
        _lastTrackId = mi?.id;
        _queryLikedState(mi);
      }
    });
    _queryLikedState(player.mediaItem.valueOrNull);
  }

  Future<void> _queryLikedState(MediaItem? mi) async {
    if (mi == null) {
      if (mounted) setState(() => _isLiked = false);
      return;
    }
    try {
      final liked = await context
          .read<LibraryItemsCubit>()
          .isTrackLiked(mediaItemToTrack(mi));
      if (mounted) setState(() => _isLiked = liked);
    } catch (_) {
      if (mounted) setState(() => _isLiked = false);
    }
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<TarangXPlayerCubit>().tarangXPlayer;
    final currentMedia = player.mediaItem.valueOrNull;
    if (currentMedia == null) return const SizedBox.shrink();

    return Tooltip(
      message: _isLiked ? 'Remove from favorites' : 'Add to favorites',
      child: IconButton(
        iconSize: 26,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            _isLiked ? MingCute.heart_fill : MingCute.heart_line,
            key: ValueKey(_isLiked),
            color: _isLiked
                ? const Color(0xFFEF4444)
                : Default_Theme.primaryColor2.withValues(alpha: 0.8),
            size: 26,
          ),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          final l10n = AppLocalizations.of(context)!;
          if (_isLiked) {
            context
                .read<LibraryItemsCubit>()
                .setTrackLiked(mediaItemToTrack(currentMedia), false);
            setState(() => _isLiked = false);
            SnackbarService.showMessage(
              l10n.playerUnliked(currentMedia.title),
            );
          } else {
            context
                .read<LibraryItemsCubit>()
                .setTrackLiked(mediaItemToTrack(currentMedia), true);
            setState(() => _isLiked = true);
            SnackbarService.showMessage(
              l10n.playerLiked(currentMedia.title),
            );
          }
        },
      ),
    );
  }
}

// ── Progress Bar ──────────────────────────────────────────────────────────────
class _PlayerProgressBar extends StatelessWidget {
  const _PlayerProgressBar();

  @override
  Widget build(BuildContext context) {
    final playerCubit = context.read<TarangXPlayerCubit>();

    return RepaintBoundary(
      child: StreamBuilder<ProgressBarStreams>(
        stream: playerCubit.progressStreams,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return GradientProgressBar.fromAccentColors(
            progress: data?.position ?? Duration.zero,
            total: data?.duration ?? Duration.zero,
            buffered: data?.buffered ?? Duration.zero,
            onSeek: playerCubit.tarangXPlayer.seek,
            isPlaying: data?.isPlaying ?? false,
            activeAccentColor: Default_Theme.accentColor1,
            inactiveAccentColor: Default_Theme.accentColor2,
            activeGradientStyle: GradientStyle.lightAndBreezy,
            inactiveGradientStyle: GradientStyle.warmAndRich,
            trackHeight: 5.5,
            thumbRadius: 7.5,
            timeLabelPadding: 6,
            timeLabelStyle: TextStyle(
              fontFamily: 'Gilroy',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Default_Theme.primaryColor2.withValues(alpha: 0.8),
            ),
            timeLabelLocation: TimeLabelLocation.below,
            inactiveTrackColor:
                Default_Theme.primaryColor2.withValues(alpha: 0.12),
            animationDuration: const Duration(milliseconds: 200),
            animationCurve: Curves.easeOutCubic,
          );
        },
      ),
    );
  }
}

// ── Universal Main Playback Controls Row ──────────────────────────────────────
class _PlayerControlsRow extends StatelessWidget {
  final TarangXMusicPlayer musicPlayer;

  const _PlayerControlsRow({required this.musicPlayer});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _ShuffleControl(),
          _SkipPreviousButton(musicPlayer: musicPlayer),
          _HeroPlayPauseButton(musicPlayer: musicPlayer),
          _SkipNextButton(musicPlayer: musicPlayer),
          const _LoopControl(),
        ],
      ),
    );
  }
}

// ── Hero Play / Pause Circular Button ─────────────────────────────────────────
class _HeroPlayPauseButton extends StatelessWidget {
  final TarangXMusicPlayer musicPlayer;

  const _HeroPlayPauseButton({required this.musicPlayer});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MiniPlayerCubit, MiniPlayerState>(
      builder: (context, state) {
        Widget iconWidget;

        if (state.isLoading || state.isResolving) {
          iconWidget = const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          );
        } else if (state.isCompleted) {
          iconWidget = const Icon(
            FontAwesome.rotate_right_solid,
            color: Colors.white,
            size: 24,
          );
        } else if (state.hasError) {
          iconWidget = const Icon(
            MingCute.warning_line,
            color: Colors.white,
            size: 28,
          );
        } else if (state.isPlaying) {
          iconWidget = const Icon(
            FontAwesome.pause_solid,
            color: Colors.white,
            size: 24,
          );
        } else {
          iconWidget = const Padding(
            padding: EdgeInsets.only(left: 3.5),
            child: Icon(
              MingCute.play_fill,
              color: Colors.white,
              size: 32,
            ),
          );
        }

        return Tooltip(
          message: state.isPlaying ? 'Pause' : 'Play',
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (state.isCompleted) {
                musicPlayer.seek(Duration.zero);
                musicPlayer.play();
              } else if (state.hasError) {
                musicPlayer.play();
              } else if (state.isPlaying) {
                musicPlayer.pause();
              } else {
                musicPlayer.play();
              }
            },
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: Default_Theme.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color:
                        Default_Theme.accentColor2.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(child: iconWidget),
            ),
          ),
        );
      },
    );
  }
}

// ── Previous / Next Track Controls ────────────────────────────────────────────
class _SkipPreviousButton extends StatelessWidget {
  final TarangXMusicPlayer musicPlayer;

  const _SkipPreviousButton({required this.musicPlayer});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Previous track',
      child: IconButton(
        iconSize: 34,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        icon: const Icon(
          MingCute.skip_previous_fill,
          color: Default_Theme.primaryColor1,
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          musicPlayer.skipToPrevious();
        },
      ),
    );
  }
}

class _SkipNextButton extends StatelessWidget {
  final TarangXMusicPlayer musicPlayer;

  const _SkipNextButton({required this.musicPlayer});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Next track',
      child: IconButton(
        iconSize: 34,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        icon: const Icon(
          MingCute.skip_forward_fill,
          color: Default_Theme.primaryColor1,
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          musicPlayer.skipToNext();
        },
      ),
    );
  }
}

// ── Shuffle Control ───────────────────────────────────────────────────────────
class _ShuffleControl extends StatelessWidget {
  const _ShuffleControl();

  @override
  Widget build(BuildContext context) {
    final player = context.read<TarangXPlayerCubit>().tarangXPlayer;

    return StreamBuilder<bool>(
      stream: player.shuffleMode,
      builder: (context, snapshot) {
        final isShuffle = snapshot.data ?? false;

        return Tooltip(
          message: isShuffle ? 'Shuffle: On' : 'Shuffle: Off',
          child: IconButton(
            iconSize: 26,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            icon: Icon(
              isShuffle ? MingCute.shuffle_2_fill : MingCute.shuffle_2_line,
              color: isShuffle
                  ? Default_Theme.accentLavender
                  : Default_Theme.primaryColor2.withValues(alpha: 0.6),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              player.shuffle(!isShuffle);
            },
          ),
        );
      },
    );
  }
}

// ── Loop / Repeat Control (Off -> All -> One) ─────────────────────────────────
class _LoopControl extends StatelessWidget {
  const _LoopControl();

  @override
  Widget build(BuildContext context) {
    final player = context.read<TarangXPlayerCubit>().tarangXPlayer;

    return StreamBuilder<LoopMode>(
      stream: player.loopMode,
      builder: (context, snapshot) {
        final loopMode = snapshot.data ?? LoopMode.off;
        IconData icon;
        Color color;
        String tooltip;

        switch (loopMode) {
          case LoopMode.off:
            icon = MingCute.repeat_line;
            color = Default_Theme.primaryColor2.withValues(alpha: 0.6);
            tooltip = 'Repeat: Off';
            break;
          case LoopMode.all:
            icon = MingCute.repeat_fill;
            color = Default_Theme.accentLavender;
            tooltip = 'Repeat: All';
            break;
          case LoopMode.one:
            icon = MingCute.repeat_one_line;
            color = Default_Theme.accentLavender;
            tooltip = 'Repeat: One';
            break;
        }

        return Tooltip(
          message: tooltip,
          child: IconButton(
            iconSize: 26,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            icon: Icon(icon, color: color),
            onPressed: () {
              HapticFeedback.selectionClick();
              if (loopMode == LoopMode.off) {
                player.setLoopMode(LoopMode.all);
              } else if (loopMode == LoopMode.all) {
                player.setLoopMode(LoopMode.one);
              } else {
                player.setLoopMode(LoopMode.off);
              }
            },
          ),
        );
      },
    );
  }
}
