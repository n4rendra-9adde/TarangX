import 'dart:developer';
import 'package:Bloomee/blocs/explore/cubit/explore_cubits.dart';
import 'package:Bloomee/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:Bloomee/blocs/lastdotfm/lastdotfm_cubit.dart';
import 'package:Bloomee/blocs/media_player/tarangx_player_cubit.dart';
import 'package:Bloomee/blocs/notification/notification_cubit.dart';
import 'package:Bloomee/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:Bloomee/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:Bloomee/core/di/service_locator.dart';
import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/core/models/media_playlist_model.dart';
import 'package:Bloomee/plugins/blocs/content/content_bloc.dart';
import 'package:Bloomee/plugins/blocs/content/content_event.dart';
import 'package:Bloomee/plugins/blocs/content/content_state.dart';
import 'package:Bloomee/plugins/blocs/plugin/plugin_bloc.dart';
import 'package:Bloomee/plugins/blocs/plugin/plugin_state.dart';
import 'package:Bloomee/screens/screen/home_views/recents_view.dart';
import 'package:Bloomee/screens/screen/home_views/setting_views/about.dart';
import 'package:Bloomee/screens/widgets/more_bottom_sheet.dart';
import 'package:Bloomee/screens/widgets/sign_board_widget.dart';
import 'package:Bloomee/screens/widgets/song_tile.dart';
import 'package:Bloomee/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Bloomee/screens/screen/home_views/notification_view.dart';
import 'package:Bloomee/screens/screen/home_views/setting_view.dart';
import 'package:Bloomee/screens/screen/home_views/timer_view.dart';
import 'package:Bloomee/core/theme/app_theme.dart';
import 'package:Bloomee/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'chart/carousal_widget.dart';
import '../widgets/horizontal_card_view.dart';
import '../widgets/tab_list_widget.dart';
import 'package:badges/badges.dart' as badges;
import 'package:Bloomee/screens/screen/common_views/playlist_view.dart';
import 'package:Bloomee/screens/widgets/language_selection_modals.dart';
import 'package:Bloomee/src/rust/api/plugin/commands.dart';
import 'package:Bloomee/src/rust/api/plugin/models.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool isUpdateChecked = false;
  late final ContentBloc _homeContentBloc;
  Future<List<Track>> lFMData = Future.value(const []);

  @override
  void initState() {
    super.initState();
    _homeContentBloc = ContentBloc(pluginService: ServiceLocator.pluginService);
    _tryLoadHomeSections();
  }

  /// Only loads home sections when both settings are ready and plugins are loaded.
  void _tryLoadHomeSections() {
    final settingsState = context.read<SettingsCubit>().state;
    if (!settingsState.settingsReady) return;

    final pluginState = context.read<PluginBloc>().state;
    final contentResolvers = pluginState.loadedContentResolvers;
    if (contentResolvers.isEmpty) return;

    final preferredId = settingsState.homePluginId;
    // If the user's preferred plugin is installed but not yet loaded, wait for it.
    // This prevents flashing the wrong plugin's home page on startup.
    if (preferredId.isNotEmpty) {
      final isAlreadyLoaded =
          contentResolvers.any((p) => p.manifest.id == preferredId);
      if (!isAlreadyLoaded) {
        final isInstalled = pluginState.availablePlugins
            .any((p) => p.manifest.id == preferredId);
        if (isInstalled) return; // Preferred plugin is loading — wait for it
      }
    }

    final pluginId = _effectiveHomePluginId(contentResolvers);

    // Don't reload if we're already showing content from this plugin.
    if (_homeContentBloc.state.activePluginId == pluginId &&
        _homeContentBloc.state.homeSections != null) {
      return;
    }

    _homeContentBloc.add(GetHomeSections(pluginId: pluginId));
  }

  String _effectiveHomePluginId(List<dynamic> loadedResolvers) {
    final preferredId = context.read<SettingsCubit>().state.homePluginId;
    final hasPreferred = preferredId.isNotEmpty &&
        loadedResolvers.any((plugin) => plugin.manifest.id == preferredId);
    return hasPreferred ? preferredId : loadedResolvers.first.manifest.id;
  }

  @override
  void dispose() {
    _homeContentBloc.close();
    super.dispose();
  }

  Future<List<Track>> fetchLFMPicks(bool state, BuildContext ctx) async {
    if (state) {
      try {
        final data = await lFMData;
        if (data.isNotEmpty) return data;
        if (ctx.mounted) {
          final pluginState = ctx.read<PluginBloc>().state;
          final priority = ctx.read<SettingsCubit>().state.resolverPriority;
          final allIds = pluginState.loadedContentResolvers
              .map((p) => p.manifest.id)
              .toList();
          final resolverIds = [
            ...priority.where(allIds.contains),
            ...allIds.where((id) => !priority.contains(id)),
          ];
          lFMData = ctx.read<LastdotfmCubit>().getRecommendedTracks(
                resolverPluginIds: resolverIds,
              );
        }
        return (await lFMData);
      } catch (e) {
        log(e.toString(), name: "ExploreScreen");
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: MultiBlocListener(
        listeners: [
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (previous, current) =>
                previous.homePluginId != current.homePluginId ||
                (!previous.settingsReady && current.settingsReady),
            listener: (context, state) {
              _homeContentBloc.add(const ClearHomeSections());
              _tryLoadHomeSections();
            },
          ),
          BlocListener<PluginBloc, PluginState>(
            listenWhen: (previous, current) {
              return previous.loadedContentResolvers !=
                      current.loadedContentResolvers ||
                  previous.loadedPluginIds != current.loadedPluginIds;
            },
            listener: (context, state) {
              if (state.loadedContentResolvers.isEmpty) {
                _homeContentBloc.add(const ClearHomeSections());
                return;
              }

              final activePluginId = _homeContentBloc.state.activePluginId;
              if (activePluginId != null &&
                  !state.loadedPluginIds.contains(activePluginId)) {
                // Active plugin was unloaded — reload from preferred.
                _homeContentBloc.add(const ClearHomeSections());
                _tryLoadHomeSections();
                return;
              }

              // Plugin list changed — check if preferred plugin is different.
              _tryLoadHomeSections();
            },
          ),
        ],
        child: Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              final pluginId = _effectiveHomePluginId(
                context.read<PluginBloc>().state.loadedContentResolvers,
              );
              _homeContentBloc.add(
                GetHomeSections(pluginId: pluginId, bypassCache: true),
              );
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1360),
                child: CustomScrollView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    const CustomDiscoverBar(),
                    SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          const CaraouselWidget(),
                          BlocBuilder<RecentlyCubit, RecentlyCubitState>(
                            builder: (context, state) {
                              if (state is RecentlyCubitInitial) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: SizedBox(
                                      height: 36,
                                      width: 36,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Default_Theme.accentColor2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (state.tracks.isNotEmpty) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ContinueListeningCard(
                                      track: state.tracks.first,
                                      queue: state.tracks,
                                    ),
                                    TabSongListWidget(
                                      category: AppLocalizations.of(context)!
                                          .exploreRecently,
                                      columnSize: 3,
                                      onSeeAll: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const HistoryView(),
                                          ),
                                        );
                                      },
                                      list: state.tracks.map((e) {
                                        return SongCardWidget(
                                          song: e,
                                          onTap: () {
                                            context
                                                .read<TarangXPlayerCubit>()
                                                .tarangXPlayer
                                                .loadPlaylist(
                                                  Playlist(
                                                    tracks: state.tracks,
                                                    title: 'Recently',
                                                  ),
                                                  idx: state.tracks.indexOf(e),
                                                  doPlay: true,
                                                );
                                          },
                                          onOptionsTap: () =>
                                              showMoreBottomSheet(
                                            context,
                                            e,
                                            showSinglePlay: true,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                );
                              }
                              return const _EmptyRecentCard();
                            },
                          ),
                          const _LanguagePlaylistsSection(),
                          BlocBuilder<SettingsCubit, SettingsState>(
                            builder: (context, state) {
                              if (state.lFMPicks) {
                                return FutureBuilder(
                                  future:
                                      fetchLFMPicks(state.lFMPicks, context),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData &&
                                        (snapshot.data?.isNotEmpty ?? false)) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 10.0),
                                        child: TabSongListWidget(
                                          list: snapshot.data!.map((e) {
                                            return SongCardWidget(
                                              song: e,
                                              onTap: () {
                                                context
                                                    .read<TarangXPlayerCubit>()
                                                    .tarangXPlayer
                                                    .loadPlaylist(
                                                      Playlist(
                                                        tracks: snapshot.data!,
                                                        title: 'Last.Fm Picks',
                                                      ),
                                                      idx: snapshot.data!
                                                          .indexOf(e),
                                                      doPlay: true,
                                                    );
                                              },
                                              onOptionsTap: () =>
                                                  showMoreBottomSheet(
                                                      context,
                                                      showSinglePlay: true,
                                                      e),
                                            );
                                          }).toList(),
                                          category:
                                              AppLocalizations.of(context)!
                                                  .exploreLastFmPicks,
                                          columnSize: 3,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          // Home sections from plugin
                          BlocBuilder<ContentBloc, ContentState>(
                            bloc: _homeContentBloc,
                            builder: (context, state) {
                              final loadedResolvers = context
                                  .read<PluginBloc>()
                                  .state
                                  .loadedContentResolvers;
                              if (loadedResolvers.isEmpty) {
                                return const SignBoardWidget(
                                  message:
                                      'No content plugin loaded.\nLoad a Content Resolver in Plugin Manager.',
                                  icon: MingCute.plugin_2_line,
                                );
                              }

                              final sections = state.homeSections ?? const [];
                              final hasSections = sections.isNotEmpty;
                              final activePluginId = state.activePluginId;
                              if (activePluginId != null &&
                                  !context
                                      .read<PluginBloc>()
                                      .state
                                      .loadedPluginIds
                                      .contains(activePluginId) &&
                                  !hasSections) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: SignBoardWidget(
                                    message:
                                        'Refreshing Discover source...\nThe previous source is no longer available.',
                                    icon: MingCute.warning_line,
                                  ),
                                );
                              }

                              if (state.homeSectionsStatus ==
                                  DetailStatus.loading) {
                                if (hasSections) {
                                  return _HomeSectionsList(
                                    sections: sections,
                                    contentBloc: _homeContentBloc,
                                    state: state,
                                  );
                                }

                                return BlocBuilder<ConnectivityCubit,
                                    ConnectivityState>(
                                  builder: (context, connState) {
                                    if (connState ==
                                        ConnectivityState.disconnected) {
                                      return const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 16),
                                        child: SignBoardWidget(
                                          message: 'No Internet Connection!',
                                          icon: MingCute.wifi_off_line,
                                        ),
                                      );
                                    }

                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 40),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Default_Theme.accentColor2,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }

                              if (state.homeSectionsStatus ==
                                  DetailStatus.error) {
                                if (hasSections) {
                                  return _HomeSectionsList(
                                    sections: sections,
                                    contentBloc: _homeContentBloc,
                                    state: state,
                                  );
                                }

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: SignBoardWidget(
                                    message: state.error ??
                                        'Failed to load home sections.',
                                    icon: MingCute.sweats_line,
                                  ),
                                );
                              }

                              if (!hasSections) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: SizedBox.shrink(),
                                );
                              }

                              return _HomeSectionsList(
                                sections: sections,
                                contentBloc: _homeContentBloc,
                                state: state,
                              );
                            },
                          ),
                          const SizedBox(height: 110),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          backgroundColor: Default_Theme.themeColor,
        ),
      ),
    );
  }
}

class _HomeSectionsList extends StatelessWidget {
  final List<Section> sections;
  final ContentBloc contentBloc;
  final ContentState state;

  const _HomeSectionsList({
    required this.sections,
    required this.contentBloc,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemExtent: 290,
      padding: const EdgeInsets.only(top: 0),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return HorizontalCardView(
          section: section,
          pluginId: contentBloc.state.activePluginId ?? '',
          canLoadMore: section.moreLink != null,
          isLoadingMore: state.isHomeSectionLoading(section.id),
          onLoadMore: section.moreLink == null
              ? null
              : () {
                  contentBloc.add(
                    LoadMoreHomeSectionItems(
                      pluginId: contentBloc.state.activePluginId ?? '',
                      sectionId: section.id,
                      moreLink: section.moreLink!,
                    ),
                  );
                },
        );
      },
    );
  }
}

class CustomDiscoverBar extends StatelessWidget {
  const CustomDiscoverBar({super.key});

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SliverAppBar(
      floating: true,
      pinned: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Default_Theme.themeColor,
      title: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Default_Theme.primaryColor2,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                l10n.exploreDiscover,
                style: const TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Default_Theme.primaryColor1,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const Spacer(),
          const NotificationIcon(),
          const SizedBox(width: 6),
          const TimerIcon(),
          const SizedBox(width: 6),
          const SettingsIcon(),
          const SizedBox(width: 6),
          const SiteIcon(),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final String? tooltip;

  const _HeaderIconButton({
    required this.child,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: Default_Theme.accentColor2.withValues(alpha: 0.15),
          highlightColor: Default_Theme.accentColor2.withValues(alpha: 0.08),
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Default_Theme.surfaceElevated.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Default_Theme.surfaceBorderSubtle,
                width: 0.8,
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationCubit, NotificationState>(
      builder: (context, state) {
        final count =
            (state is! NotificationInitial) ? state.notifications.length : 0;
        final iconWidget = const Icon(
          MingCute.notification_line,
          color: Default_Theme.primaryColor1,
          size: 19.0,
        );

        return _HeaderIconButton(
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationView()),
            );
          },
          child: count > 0
              ? badges.Badge(
                  badgeContent: Text(
                    count.toString(),
                    style: const TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  badgeStyle: const badges.BadgeStyle(
                    badgeColor: Default_Theme.accentColor2,
                    shape: badges.BadgeShape.circle,
                    padding: EdgeInsets.all(3.5),
                  ),
                  position: badges.BadgePosition.topEnd(top: -6, end: -6),
                  child: iconWidget,
                )
              : iconWidget,
        );
      },
    );
  }
}

class TimerIcon extends StatelessWidget {
  const TimerIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return _HeaderIconButton(
      tooltip: 'Sleep Timer',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TimerView()),
        );
      },
      child: const Icon(
        MingCute.stopwatch_line,
        color: Default_Theme.primaryColor1,
        size: 19.0,
      ),
    );
  }
}

class SettingsIcon extends StatelessWidget {
  const SettingsIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return _HeaderIconButton(
      tooltip: 'Settings',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsView()),
        );
      },
      child: const Icon(
        MingCute.settings_3_line,
        color: Default_Theme.primaryColor1,
        size: 19.0,
      ),
    );
  }
}

class SiteIcon extends StatelessWidget {
  const SiteIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return _HeaderIconButton(
      tooltip: 'About TarangX',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const About()),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.0),
        child: Image.asset(
          "assets/icons/tarangx_logo.png",
          width: 22.0,
          height: 22.0,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class ContinueListeningCard extends StatelessWidget {
  final Track track;
  final List<Track> queue;

  const ContinueListeningCard({
    super.key,
    required this.track,
    required this.queue,
  });

  @override
  Widget build(BuildContext context) {
    final playerCubit = context.read<TarangXPlayerCubit>();
    final thumbUrl = track.thumbnail.urlLow ?? track.thumbnail.url;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        gradient: Default_Theme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Default_Theme.surfaceBorderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Default_Theme.accentColor2.withValues(alpha: 0.1),
          highlightColor: Default_Theme.accentColor2.withValues(alpha: 0.05),
          onTap: () {
            final currentId = playerCubit.tarangXPlayer.mediaItem.value?.id;
            if (currentId == track.id) {
              context.read<PlayerOverlayCubit>().showPlayer();
            } else {
              playerCubit.tarangXPlayer.loadPlaylist(
                Playlist(tracks: queue, title: 'Continue Listening'),
                idx: 0,
                doPlay: true,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 66,
                    height: 66,
                    child: LoadImageCached(
                      imageUrl: thumbUrl,
                      fallbackUrl: track.thumbnail.url,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            MingCute.music_2_fill,
                            size: 13,
                            color: Default_Theme.accentLavender,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'CONTINUE LISTENING',
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                              color: Default_Theme.accentLavender,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Default_Theme.primaryColor1,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.artists.map((a) => a.name).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Default_Theme.primaryColor2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Play/Pause button
                StreamBuilder(
                  stream: playerCubit.tarangXPlayer.playbackState,
                  builder: (context, snapshot) {
                    final isCurrentTrack =
                        playerCubit.tarangXPlayer.mediaItem.value?.id ==
                            track.id;
                    final isPlaying =
                        isCurrentTrack && (snapshot.data?.playing ?? false);

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (isCurrentTrack) {
                          isPlaying
                              ? playerCubit.tarangXPlayer.pause()
                              : playerCubit.tarangXPlayer.play();
                        } else {
                          playerCubit.tarangXPlayer.loadPlaylist(
                            Playlist(
                                tracks: queue, title: 'Continue Listening'),
                            idx: 0,
                            doPlay: true,
                          );
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: Default_Theme.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Default_Theme.accentColor2
                                  .withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            isPlaying
                                ? MingCute.pause_fill
                                : MingCute.play_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                // Options button
                IconButton(
                  icon: const Icon(
                    MingCute.more_2_fill,
                    size: 20,
                    color: Default_Theme.primaryColor2,
                  ),
                  splashRadius: 18,
                  onPressed: () => showMoreBottomSheet(
                    context,
                    track,
                    showSinglePlay: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecentCard extends StatelessWidget {
  const _EmptyRecentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Default_Theme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Default_Theme.surfaceBorderSubtle,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Default_Theme.accentColor2.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                MingCute.sparkles_fill,
                size: 22,
                color: Default_Theme.accentLavender,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Welcome to TarangX',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Default_Theme.primaryColor1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Play songs from Search or Charts to build your history.',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Default_Theme.primaryColor2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePlaylistsSection extends StatefulWidget {
  const _LanguagePlaylistsSection();

  @override
  State<_LanguagePlaylistsSection> createState() =>
      _LanguagePlaylistsSectionState();
}

class _LanguagePlaylistsSectionState extends State<_LanguagePlaylistsSection> {
  String _activeTab = 'All';

  Future<void> _handlePlaylistTap(
    BuildContext context,
    CuratedLanguagePlaylistData playlist,
  ) async {
    final pluginState = context.read<PluginBloc>().state;
    final resolvers = pluginState.loadedContentResolvers;
    if (resolvers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable a content plugin in Plugin Manager.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final preferredId = context.read<SettingsCubit>().state.homePluginId;
    final pluginId = preferredId.isNotEmpty &&
            resolvers.any((p) => p.manifest.id == preferredId)
        ? preferredId
        : resolvers.first.manifest.id;

    // Try resolving real remote playlist from plugin
    try {
      final response = await ServiceLocator.pluginService.execute(
        pluginId: pluginId,
        request: PluginRequest.contentResolver(
          ContentResolverCommand.search(
            query: playlist.searchQuery,
            filter: ContentSearchFilter.playlist,
          ),
        ),
      );

      PlaylistSummary? matched;
      response.when(
        search: (results) {
          for (final item in results.items) {
            if (item is MediaItem_Playlist) {
              matched = item.field0;
              break;
            }
          }
        },
        trackDetails: (_) {},
        albumDetails: (_) {},
        artistDetails: (_) {},
        playlistDetails: (_) {},
        streams: (_) {},
        moreTracks: (_) {},
        moreAlbums: (_) {},
        homeSections: (_) {},
        loadMoreItems: (_) {},
        charts: (_) {},
        chartDetails: (_) {},
        segments: (_) {},
        lyricsResult: (_) {},
        lyricsSearchResults: (_) {},
        lyricsById: (_, __) {},
        suggestions: (_) {},
        canHandle: (_) {},
        collectionInfo: (_) {},
        importTracks: (_) {},
        ack: () {},
      );

      if (matched != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnlPlaylistView(
              playlist: matched!,
              pluginId: pluginId,
            ),
          ),
        );
        return;
      }
    } catch (e) {
      log('Playlist search error: $e', name: '_LanguagePlaylistsSection');
    }

    // Fallback: open OnlPlaylistView with curated playlist summary
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlPlaylistView(
            playlist: PlaylistSummary(
              id: playlist.id,
              title: playlist.title,
              owner: '${playlist.language} Music',
              thumbnail: Artwork(
                url: playlist.coverUrl,
                layout: ImageLayout.square,
              ),
            ),
            pluginId: pluginId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (prev, curr) =>
          prev.musicLanguages != curr.musicLanguages ||
          prev.homePluginId != curr.homePluginId,
      builder: (context, settingsState) {
        final languages = settingsState.musicLanguages.isEmpty
            ? const ['Hindi', 'English']
            : settingsState.musicLanguages;

        if (_activeTab != 'All' && !languages.contains(_activeTab)) {
          _activeTab = 'All';
        }

        // Filter playlists by active languages
        final visiblePlaylists = kCuratedLanguagePlaylists.where((p) {
          if (_activeTab == 'All') {
            return languages.contains(p.language);
          }
          return p.language == _activeTab;
        }).toList();

        return Container(
          margin: const EdgeInsets.only(top: 14, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 16, 6),
                child: Row(
                  children: [
                    Container(
                      width: 3.5,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Default_Theme.accentColor2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Playlists in Your Languages',
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Default_Theme.primaryColor1,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Curated for ${languages.join(", ")}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Default_Theme.primaryColor2
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick edit button
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(
                        MingCute.settings_6_line,
                        size: 15,
                        color: Default_Theme.accentLavender,
                      ),
                      label: const Text(
                        'Edit',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Default_Theme.accentLavender,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        MusicLanguagePickerModal.show(
                          context: context,
                          currentLanguages: languages,
                          onSaved: (newLangs) {
                            context
                                .read<SettingsCubit>()
                                .setMusicLanguages(newLangs);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Filter pills row
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildPill(
                      label: 'All (${languages.length})',
                      isSelected: _activeTab == 'All',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _activeTab = 'All');
                      },
                    ),
                    ...languages.map(
                      (lang) => _buildPill(
                        label: lang,
                        isSelected: _activeTab == lang,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activeTab = lang);
                        },
                      ),
                    ),
                    // Add more languages pill
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          MusicLanguagePickerModal.show(
                            context: context,
                            currentLanguages: languages,
                            onSaved: (newLangs) {
                              context
                                  .read<SettingsCubit>()
                                  .setMusicLanguages(newLangs);
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Default_Theme.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Default_Theme.surfaceBorderSubtle,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                MingCute.add_line,
                                size: 14,
                                color: Default_Theme.primaryColor2,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Languages',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Default_Theme.primaryColor2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Horizontal playlist cards
              if (visiblePlaylists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Text(
                    'No playlists found for the selected language.',
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 13,
                      color: Default_Theme.primaryColor2,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 224,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: visiblePlaylists.length,
                    itemBuilder: (context, idx) {
                      final item = visiblePlaylists[idx];
                      return _LanguagePlaylistCard(
                        playlist: item,
                        onTap: () => _handlePlaylistTap(context, item),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: isSelected ? Default_Theme.brandGradient : null,
              color: isSelected
                  ? null
                  : Default_Theme.primaryColor2.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color:
                            Default_Theme.accentColor2.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : Default_Theme.primaryColor1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguagePlaylistCard extends StatefulWidget {
  final CuratedLanguagePlaylistData playlist;
  final VoidCallback onTap;

  const _LanguagePlaylistCard({
    required this.playlist,
    required this.onTap,
  });

  @override
  State<_LanguagePlaylistCard> createState() => _LanguagePlaylistCardState();
}

class _LanguagePlaylistCardState extends State<_LanguagePlaylistCard> {
  bool _isHovering = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () async {
          setState(() => _isLoading = true);
          try {
            widget.onTap();
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: SizedBox(
            width: 154,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Artwork stack
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 154,
                        height: 154,
                        child: LoadImageCached(
                          imageUrl: widget.playlist.coverUrl,
                          fallbackUrl: widget.playlist.coverUrl,
                        ),
                      ),
                      // Language Tag
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            widget.playlist.language.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Gilroy',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Default_Theme.accentLavender,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                      // Hover/Loading play indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 154,
                        height: 154,
                        color: (_isHovering || _isLoading)
                            ? Colors.black.withValues(alpha: 0.45)
                            : Colors.transparent,
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : AnimatedOpacity(
                                  opacity: _isHovering ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 150),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: Default_Theme.brandGradient,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Default_Theme.accentColor2
                                              .withValues(alpha: 0.4),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        MingCute.play_fill,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Title
                Text(
                  widget.playlist.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Default_Theme.primaryColor1,
                  ),
                ),
                const SizedBox(height: 2),
                // Subtitle
                Text(
                  widget.playlist.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: Default_Theme.primaryColor2.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

