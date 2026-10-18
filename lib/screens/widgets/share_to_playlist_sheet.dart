import 'dart:developer';

import 'package:Bloomee/blocs/library/cubit/library_items_cubit.dart';
import 'package:Bloomee/core/constants/setting_keys.dart';
import 'package:Bloomee/core/di/service_locator.dart';
import 'package:Bloomee/core/models/exported.dart';
import 'package:Bloomee/core/models/media_playlist_model.dart';
import 'package:Bloomee/core/theme/app_theme.dart';
import 'package:Bloomee/l10n/app_localizations.dart';
import 'package:Bloomee/screens/widgets/create_playlist_bottomsheet.dart';
import 'package:Bloomee/services/share/android_share_service.dart';
import 'package:Bloomee/services/share/shared_music_models.dart';
import 'package:Bloomee/src/rust/api/plugin/commands.dart';
import 'package:Bloomee/src/rust/api/plugin/models.dart';
import 'package:Bloomee/src/rust/api/plugin/types.dart';
import 'package:Bloomee/utils/load_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

class ShareToPlaylistSheet extends StatefulWidget {
  final String rawContent;
  final AndroidShareService shareService;

  const ShareToPlaylistSheet({
    super.key,
    required this.rawContent,
    this.shareService = AndroidShareService.defaultService,
  });

  static Future<void> show(
    BuildContext context, {
    required String rawContent,
    AndroidShareService shareService = AndroidShareService.defaultService,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareToPlaylistSheet(
        rawContent: rawContent,
        shareService: shareService,
      ),
    );
  }

  @override
  State<ShareToPlaylistSheet> createState() => _ShareToPlaylistSheetState();
}

class _ShareToPlaylistSheetState extends State<ShareToPlaylistSheet> {
  bool _isLoading = true;
  SharedMusicResolution? _resolution;
  Track? _selectedTrack;

  // Fallback search state
  late final TextEditingController _searchController;
  bool _isSearching = false;
  List<Track> _searchResults = [];

  // Playlist membership tracking
  final Set<String> _songInPlaylists = {};
  final Set<String> _pendingOps = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _resolveContent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _resolveContent() async {
    setState(() => _isLoading = true);
    try {
      final res =
          await widget.shareService.resolveSharedContent(widget.rawContent);
      if (!mounted) return;

      setState(() {
        _resolution = res;
        _isLoading = false;
        if (res.isSuccess && res.track != null) {
          _selectedTrack = res.track;
        } else {
          _searchController.text = res.suggestedQuery ?? '';
          if (_searchController.text.trim().isNotEmpty) {
            _performFallbackSearch(_searchController.text.trim());
          }
        }
      });

      if (_selectedTrack != null) {
        await _checkPlaylistMembership(_selectedTrack!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _resolution = SharedMusicResolution(
          status: SharedMusicResolutionStatus.failed,
          message: 'An unexpected error occurred while resolving shared music.',
          payload: ExtractedSharePayload.fromText(widget.rawContent),
        );
      });
    }
  }

  Future<void> _checkPlaylistMembership(Track track) async {
    try {
      final names = await context
          .read<LibraryItemsCubit>()
          .getPlaylistsContainingTrack(track.id);
      if (!mounted) return;
      setState(() {
        _songInPlaylists.clear();
        _songInPlaylists.addAll(names);
      });
    } catch (_) {}
  }

  Future<void> _performFallbackSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isSearching = true);
    final results = <Track>[];

    try {
      final pluginService = ServiceLocator.pluginService;
      final available = await pluginService.getAvailablePlugins();
      final loadedIds = pluginService.getLoadedPlugins().toSet();

      final resolvers = available.where((p) =>
          p.pluginType == PluginType.contentResolver &&
          loadedIds.contains(p.manifest.id));

      for (final plugin in resolvers) {
        try {
          final res = await pluginService.execute(
            pluginId: plugin.manifest.id,
            request: PluginRequest.contentResolver(
              ContentResolverCommand.search(
                query: trimmed,
                filter: ContentSearchFilter.track,
              ),
            ),
          ).timeout(const Duration(seconds: 8));

          if (res is PluginResponse_Search) {
            for (final item in res.field0.items) {
              if (item is MediaItem_Track) {
                results.add(item.field0);
              }
            }
          }
          if (results.isNotEmpty) break;
        } catch (_) {}
      }

      // Also search local library as fallback if plugin returned empty.
      if (results.isEmpty && mounted) {
        final local = await context.read<LibraryItemsCubit>().searchTracks(trimmed);
        results.addAll(local);
      }
    } catch (e) {
      log('Fallback search error: $e', name: 'ShareToPlaylistSheet');
    }

    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _onSelectTrack(Track track) async {
    setState(() {
      _selectedTrack = track;
    });
    await _checkPlaylistMembership(track);
  }

  Future<void> _togglePlaylist(
      PlaylistItemProperties playlist, Track track) async {
    final playlistName = playlist.playlistName;
    if (_pendingOps.contains(playlistName)) return;

    setState(() => _pendingOps.add(playlistName));

    final isAlreadyIn = _songInPlaylists.contains(playlistName);
    try {
      if (isAlreadyIn) {
        await context.read<LibraryItemsCubit>().removeFromPlaylist(
              track,
              playlistName,
              showSnackbar: true,
            );
        if (mounted) {
          setState(() => _songInPlaylists.remove(playlistName));
        }
      } else {
        final added = await context.read<LibraryItemsCubit>().addToPlaylist(
              track,
              playlistName,
              showSnackbar: true,
            );
        if (mounted && added) {
          setState(() => _songInPlaylists.add(playlistName));
        }
      }
    } catch (e) {
      log('Playlist toggle failed: $e', name: 'ShareToPlaylistSheet');
    } finally {
      if (mounted) {
        setState(() => _pendingOps.remove(playlistName));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Default_Theme.themeColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Default_Theme.primaryColor1.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Default_Theme.primaryColor1.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    MingCute.share_forward_line,
                    color: Default_Theme.accentColor2,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Add Shared Music',
                    style: Default_Theme.secondoryTextStyleMedium.merge(
                      const TextStyle(
                        color: Default_Theme.primaryColor1,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Default_Theme.primaryColor1,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Sheet Body
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildBody(l10n),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Default_Theme.accentColor2,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Identifying shared music...',
              style: Default_Theme.secondoryTextStyleMedium.merge(
                const TextStyle(
                  color: Default_Theme.primaryColor1,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scanning link with active content resolvers',
              textAlign: TextAlign.center,
              style: Default_Theme.secondoryTextStyle.merge(
                TextStyle(
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedTrack != null) {
      return _buildTrackSelectedView(l10n, _selectedTrack!);
    }

    return _buildFallbackSearchView(l10n);
  }

  Widget _buildTrackSelectedView(AppLocalizations l10n, Track track) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Track Preview Card
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Default_Theme.primaryColor1.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Default_Theme.accentColor2.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: LoadImageCached(
                    imageUrl: track.thumbnail.urlLow ?? track.thumbnail.url,
                    fallbackUrl: track.thumbnail.urlLow ?? track.thumbnail.url,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Default_Theme.secondoryTextStyleMedium.merge(
                        const TextStyle(
                          color: Default_Theme.primaryColor1,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artists.map((a) => a.name).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Default_Theme.secondoryTextStyle.merge(
                        TextStyle(
                          color:
                              Default_Theme.primaryColor1.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_resolution?.status != SharedMusicResolutionStatus.success)
                IconButton(
                  tooltip: 'Change Song',
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Default_Theme.accentColor2,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedTrack = null;
                    });
                  },
                ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Choose a Playlist to Add',
                style: Default_Theme.secondoryTextStyleMedium.merge(
                  const TextStyle(
                    color: Default_Theme.primaryColor1,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded,
                    size: 18, color: Default_Theme.accentColor2),
                label: Text(
                  l10n.playlistCreateNew,
                  style: const TextStyle(
                    color: Default_Theme.accentColor2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => createPlaylistDialog(context),
              ),
            ],
          ),
        ),

        // Playlist List
        Flexible(
          child: BlocBuilder<LibraryItemsCubit, LibraryItemsState>(
            builder: (context, libraryState) {
              final userPlaylists = libraryState.playlists.where((p) {
                return p.type == PlaylistType.userPlaylist &&
                    p.playlistName != 'recently_played' &&
                    p.playlistName != SettingKeys.downloadPlaylist &&
                    p.playlistName != SettingKeys.localMusicPlaylist;
              }).toList()
                ..sort((a, b) => a.playlistName
                    .toLowerCase()
                    .compareTo(b.playlistName.toLowerCase()));

              if (userPlaylists.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          MingCute.playlist_line,
                          color: Colors.white30,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.playlistCreateFirstOne,
                          style: TextStyle(
                            color: Default_Theme.primaryColor1
                                .withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Default_Theme.accentColor2,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.playlistCreateNew),
                          onPressed: () => createPlaylistDialog(context),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                physics: const BouncingScrollPhysics(),
                itemCount: userPlaylists.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final playlist = userPlaylists[index];
                  final isInPlaylist =
                      _songInPlaylists.contains(playlist.playlistName);
                  final isPending =
                      _pendingOps.contains(playlist.playlistName);

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: LoadImageCached(
                          imageUrl: playlist.coverImgUrl ?? '',
                          fallbackUrl: playlist.coverImgUrl ?? '',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    title: Text(
                      playlist.playlistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Default_Theme.secondoryTextStyleMedium.merge(
                        const TextStyle(
                          color: Default_Theme.primaryColor1,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    subtitle: Text(
                      playlist.subTitle ?? 'Playlist',
                      style: TextStyle(
                        color:
                            Default_Theme.primaryColor1.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    trailing: isPending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Default_Theme.accentColor1,
                            ),
                          )
                        : AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isInPlaylist
                                  ? Default_Theme.accentColor1
                                      .withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isInPlaylist
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              color: isInPlaylist
                                  ? Default_Theme.accentColor1
                                  : Colors.white60,
                              size: 18,
                            ),
                          ),
                    onTap: isPending
                        ? null
                        : () => _togglePlaylist(playlist, track),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackSearchView(AppLocalizations l10n) {
    final message = _resolution?.message ??
        'Could not automatically resolve this link. You can search for the track below:';
    final isInstagram =
        _resolution?.payload.type == SharedPayloadType.instagramReel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Information Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isInstagram
                  ? const Color(0xFFE1306C).withValues(alpha: 0.12)
                  : Default_Theme.accentColor2.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isInstagram
                    ? const Color(0xFFE1306C).withValues(alpha: 0.3)
                    : Default_Theme.accentColor2.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isInstagram
                      ? FontAwesome.instagram_brand
                      : MingCute.information_line,
                  color: isInstagram
                      ? const Color(0xFFE1306C)
                      : Default_Theme.accentColor2,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Default_Theme.primaryColor1.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search Field
          Container(
            decoration: BoxDecoration(
              color: Default_Theme.primaryColor1.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: Default_Theme.primaryColor1,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search song title or artist...',
                hintStyle: TextStyle(
                  color: Default_Theme.primaryColor1.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Default_Theme.accentColor2,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Default_Theme.accentColor2,
                    size: 20,
                  ),
                  onPressed: () =>
                      _performFallbackSearch(_searchController.text),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: _performFallbackSearch,
            ),
          ),
          const SizedBox(height: 12),

          // Results Section
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(
                  color: Default_Theme.accentColor2,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Matching Song:',
                    style: TextStyle(
                      color:
                          Default_Theme.primaryColor1.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length.clamp(0, 5),
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final song = _searchResults[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: LoadImageCached(
                                imageUrl: song.thumbnail.urlLow ??
                                    song.thumbnail.url,
                                fallbackUrl: song.thumbnail.urlLow ??
                                    song.thumbnail.url,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Default_Theme.primaryColor1,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            song.artists.map((a) => a.name).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Default_Theme.primaryColor1
                                  .withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Default_Theme.accentColor2,
                            size: 14,
                          ),
                          onTap: () => _onSelectTrack(song),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          else if (_searchController.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No matching songs found for "${_searchController.text.trim()}".\nTry adjusting your search terms.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
