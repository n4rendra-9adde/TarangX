// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:Bloomee/blocs/recommendation/cubit/recommendation_cubit.dart';
import 'package:Bloomee/core/di/service_locator.dart';
import 'package:Bloomee/core/theme/app_theme.dart';
import 'package:Bloomee/screens/screen/home_views/setting_views/setting_shared_widgets.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

class PrivacySettings extends StatelessWidget {
  const PrivacySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Default_Theme.themeColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Default_Theme.primaryColor1),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Privacy & Taste Profile',
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ).merge(Default_Theme.secondoryTextStyle),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: StreamBuilder(
            stream: ServiceLocator.signalCollector.profileStream,
            initialData: ServiceLocator.signalCollector.currentProfile,
            builder: (context, snapshot) {
              final profile = snapshot.data ?? ServiceLocator.signalCollector.currentProfile;
              final artistCount = profile.artistAffinities.length;
              final dislikedCount = profile.dislikedTrackIds.length;
              final blockedArtistCount = profile.dislikedArtistNames.length;
              final likedCount = profile.likedTrackIds.length;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // ── Section 1: Privacy Guarantee Banner ──
                  const SettingSectionHeader(label: 'ON-DEVICE PRIVACY'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Default_Theme.accentColor2.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Default_Theme.accentColor2.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Default_Theme.accentColor2.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            MingCute.shield_shape_fill,
                            color: Default_Theme.accentColor2,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Zero Cloud Telemetry',
                                style: Default_Theme.secondoryTextStyle.copyWith(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your listening history, preferences, and recommendation profiles are computed and stored 100% locally on your device. TarangX never transmits your musical tastes to third parties or advertising brokers.',
                                style: Default_Theme.secondoryTextStyle.copyWith(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Section 2: Taste Profile Insights ──
                  const SettingSectionHeader(label: 'LOCAL TASTE PROFILE'),
                  SettingCard(
                    children: [
                      SettingNavTile(
                        icon: MingCute.sparkles_fill,
                        title: 'Recommendation Status',
                        subtitle: profile.isColdStart
                            ? 'Cold Start (Relying on language preferences and liked songs)'
                            : 'Personalized ($artistCount learned artist ${artistCount == 1 ? 'affinity' : 'affinities'})',
                        onTap: () {},
                      ),
                      const SettingDivider(),
                      SettingNavTile(
                        icon: MingCute.heart_fill,
                        title: 'Library Likes Considered',
                        subtitle: '$likedCount songs in your Liked playlist are boosting recommendations',
                        onTap: () {},
                      ),
                      if (dislikedCount > 0 || blockedArtistCount > 0) ...[
                        const SettingDivider(),
                        SettingNavTile(
                          icon: MingCute.forbid_circle_fill,
                          title: 'Excluded from Recommendations',
                          subtitle: '$dislikedCount hidden ${dislikedCount == 1 ? 'song' : 'songs'} • $blockedArtistCount blocked ${blockedArtistCount == 1 ? 'artist' : 'artists'}',
                          onTap: () => _confirmClearDislikes(context),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Section 3: Dislikes / Hidden Management ──
                  if (dislikedCount > 0 || blockedArtistCount > 0) ...[
                    const SettingSectionHeader(label: 'EXCLUSIONS MANAGEMENT'),
                    SettingCard(
                      children: [
                        SettingNavTile(
                          icon: MingCute.refresh_1_line,
                          title: 'Clear Hidden Songs & Blocked Artists',
                          subtitle: 'Unhide all $dislikedCount songs and $blockedArtistCount artists you previously asked TarangX not to recommend.',
                          onTap: () => _confirmClearDislikes(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Section 4: Data Management & Reset Taste Profile ──
                  const SettingSectionHeader(label: 'DATA MANAGEMENT'),
                  SettingCard(
                    children: [
                      SettingDestructiveTile(
                        icon: MingCute.delete_2_fill,
                        title: 'Reset Taste Profile',
                        subtitle: 'Clear locally learned listening signals and artist affinities. Your liked songs, playlists, and downloads remain safe.',
                        onTap: () => _confirmResetTasteProfile(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmResetTasteProfile(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 24, 24, 24),
        surfaceTintColor: const Color.fromARGB(255, 24, 24, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Taste Profile?',
          style: Default_Theme.secondoryTextStyle.merge(
            const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action clears all learned recommendation signals derived from your listening history, including:',
              style: Default_Theme.secondoryTextStyle.merge(
                const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            _bulletItem('• Artist affinity scores and taste weights'),
            _bulletItem('• Track play, completion, and skip counts'),
            _bulletItem('• Repetition penalties and session signals'),
            const SizedBox(height: 14),
            Text(
              'Your personal music library will NOT be deleted:',
              style: Default_Theme.secondoryTextStyle.merge(
                const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _preservedItem('✓ Liked songs and custom playlists remain intact'),
            _preservedItem('✓ Downloaded offline tracks remain untouched'),
            _preservedItem('✓ Music language preferences are preserved'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: Default_Theme.secondoryTextStyle.merge(
                const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset Taste Profile'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await context.read<RecommendationCubit>().resetTasteProfile();
      if (context.mounted) {
        if (success) {
          SnackbarService.showMessage('Taste profile reset successfully.');
        } else {
          SnackbarService.showMessage('Failed to reset taste profile.');
        }
      }
    }
  }

  Future<void> _confirmClearDislikes(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 24, 24, 24),
        surfaceTintColor: const Color.fromARGB(255, 24, 24, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Unhide Songs & Artists?',
          style: Default_Theme.secondoryTextStyle.merge(
            const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        content: Text(
          'This will remove all exclusions and allow previously hidden songs and blocked artists to appear in recommendations again.',
          style: Default_Theme.secondoryTextStyle.merge(
            const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: Default_Theme.secondoryTextStyle.merge(
                const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Default_Theme.accentColor2,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unhide All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<RecommendationCubit>().clearDislikes();
      if (context.mounted) {
        SnackbarService.showMessage('Hidden songs and blocked artists have been unhidden.');
      }
    }
  }

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 3),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
    );
  }

  Widget _preservedItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 3),
      child: Text(
        text,
        style: const TextStyle(
          color: Default_Theme.accentColor2,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
