import 'package:Bloomee/blocs/player_overlay/player_overlay_cubit.dart';
import 'package:Bloomee/screens/widgets/player_overlay_wrapper.dart';
import 'package:Bloomee/screens/widgets/mini_player_widget.dart';
import 'package:Bloomee/core/theme/app_theme.dart';
import 'package:Bloomee/l10n/app_localizations.dart';
import 'package:Bloomee/screens/screen/home_views/setting_views/about.dart';
import 'package:Bloomee/screens/screen/home_views/setting_view.dart';
import 'package:Bloomee/screens/screen/home_views/timer_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';

class GlobalFooter extends StatelessWidget {
  const GlobalFooter({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    context.watch<PlayerOverlayCubit>();
    final width = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile || width < 540;
    final isExpandedDesktop = width >= 840;

    return PlayerOverlayWrapper(
      child: BackButtonListener(
        // FIX H-04: Back button priority order:
        // ① Navigator routes (FullscreenLyricsView, PlayerSettings, TimerView, etc.)
        // ② UpNext panel collapse
        // ③ Player overlay hide
        // ④ GoRouter shell navigation
        // ⑤ System exit
        //
        // Previously the handler short-circuited at step ③ whenever the player
        // was visible, swallowing Navigator pops and causing sub-screens to
        // appear orphaned over a hidden/collapsed player.
        onBackButtonPressed: () async {
          final overlayC = context.read<PlayerOverlayCubit>();
          final router = GoRouter.of(context);

          // ① Navigator MUST have first priority — always.
          if (router.canPop()) {
            router.pop();
            return true;
          }

          // ② Collapse UpNext panel if expanded (player must be visible).
          if (overlayC.state && overlayC.collapseUpNextPanel()) {
            return true;
          }

          // ③ Hide the player overlay.
          if (overlayC.state) {
            overlayC.hidePlayer();
            return true;
          }

          // ④ Let PopScope handle tab/exit navigation below.
          return false;
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _handleHardwareBackPress(context);
          },
          child: Scaffold(
            backgroundColor: Default_Theme.themeColor,
            drawerScrimColor: Default_Theme.themeColor,
            body: isMobile
                ? _AnimatedPageView(navigationShell: navigationShell)
                : Row(
                    children: [
                      isExpandedDesktop
                          ? DesktopSidebar(navigationShell: navigationShell)
                          : VerticalNavBar(navigationShell: navigationShell),
                      Expanded(
                        child:
                            _AnimatedPageView(navigationShell: navigationShell),
                      ),
                    ],
                  ),
            bottomNavigationBar: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayerWidget(),
                  if (isMobile)
                    HorizontalNavBar(navigationShell: navigationShell),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handles PopScope back presses using the same priority order as
  /// BackButtonListener above.
  Future<void> _handleHardwareBackPress(BuildContext context) async {
    final overlayC = context.read<PlayerOverlayCubit>();
    final router = GoRouter.of(context);

    // ① Navigator routes first
    if (router.canPop()) {
      router.pop();
      return;
    }

    // ② Collapse UpNext panel
    if (overlayC.state && overlayC.collapseUpNextPanel()) return;

    // ③ Hide player
    if (overlayC.state) {
      overlayC.hidePlayer();
      return;
    }

    // ④ Navigate to home tab
    if (navigationShell.currentIndex != 0) {
      navigationShell.goBranch(0);
      return;
    }

    // ⑤ Exit app
    if (context.mounted) {
      await SystemNavigator.pop();
    }
  }
}

class _AnimatedPageView extends StatefulWidget {
  const _AnimatedPageView({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<_AnimatedPageView> createState() => _AnimatedPageViewState();
}

class _AnimatedPageViewState extends State<_AnimatedPageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.navigationShell.currentIndex;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(_AnimatedPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != _previousIndex) {
      _previousIndex = widget.navigationShell.currentIndex;
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.navigationShell,
      ),
    );
  }
}

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        border: const Border(
          right: BorderSide(
            color: AppTheme.surfaceBorderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icons/tarangx_logo.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TarangX',
                      style: AppTheme.brandTextStyle.copyWith(
                        fontSize: 19,
                        color: AppTheme.primaryColor1,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.accentViolet.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DARK LUXURY',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppTheme.accentLavender,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Navigation destinations
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _DesktopNavItem(
                  icon: MingCute.home_4_fill,
                  label: l10n.navHome,
                  isSelected: navigationShell.currentIndex == 0,
                  onTap: () => navigationShell.goBranch(0),
                ),
                _DesktopNavItem(
                  icon: MingCute.book_5_fill,
                  label: l10n.navLibrary,
                  isSelected: navigationShell.currentIndex == 1,
                  onTap: () => navigationShell.goBranch(1),
                ),
                _DesktopNavItem(
                  icon: MingCute.search_2_fill,
                  label: l10n.navSearch,
                  isSelected: navigationShell.currentIndex == 2,
                  onTap: () => navigationShell.goBranch(2),
                ),
                _DesktopNavItem(
                  icon: MingCute.music_2_fill,
                  label: l10n.navLocal,
                  isSelected: navigationShell.currentIndex == 3,
                  onTap: () => navigationShell.goBranch(3),
                ),
                _DesktopNavItem(
                  icon: MingCute.folder_download_fill,
                  label: l10n.navOffline,
                  isSelected: navigationShell.currentIndex == 4,
                  onTap: () => navigationShell.goBranch(4),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Bottom quick actions
          const Divider(
            color: AppTheme.surfaceBorderSubtle,
            height: 1,
            indent: 16,
            endIndent: 16,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _DesktopQuickAction(
                  icon: MingCute.stopwatch_line,
                  label: 'Sleep Timer',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TimerView()),
                  ),
                ),
                _DesktopQuickAction(
                  icon: MingCute.settings_3_line,
                  label: 'Settings',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsView()),
                  ),
                ),
                _DesktopQuickAction(
                  icon: MingCute.information_line,
                  label: 'About TarangX',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const About()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _DesktopNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DesktopNavItem> createState() => _DesktopNavItemState();
}

class _DesktopNavItemState extends State<_DesktopNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppTheme.accentViolet.withValues(alpha: 0.16)
                  : (_isHovered
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isSelected
                    ? AppTheme.accentViolet.withValues(alpha: 0.32)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 20,
                  color: widget.isSelected
                      ? AppTheme.accentLavender
                      : (_isHovered
                          ? AppTheme.primaryColor1
                          : AppTheme.primaryColor2),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    fontWeight:
                        widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isSelected
                        ? AppTheme.primaryColor1
                        : (_isHovered
                            ? AppTheme.primaryColor1
                            : AppTheme.primaryColor2),
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

class _DesktopQuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DesktopQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_DesktopQuickAction> createState() => _DesktopQuickActionState();
}

class _DesktopQuickActionState extends State<_DesktopQuickAction> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: _isHovered
                      ? AppTheme.primaryColor1
                      : AppTheme.primaryColor2,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _isHovered
                        ? AppTheme.primaryColor1
                        : AppTheme.primaryColor2,
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

class VerticalNavBar extends StatelessWidget {
  const VerticalNavBar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(
            color: AppTheme.surfaceBorderSubtle,
            width: 1,
          ),
        ),
      ),
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icons/tarangx_logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.cover,
            ),
          ),
        ),
        destinations: [
          NavigationRailDestination(
            icon: const Icon(MingCute.home_4_fill),
            label: Text(l10n.navHome),
          ),
          NavigationRailDestination(
            icon: const Icon(MingCute.book_5_fill),
            label: Text(l10n.navLibrary),
          ),
          NavigationRailDestination(
            icon: const Icon(MingCute.search_2_fill),
            label: Text(l10n.navSearch),
          ),
          NavigationRailDestination(
            icon: const Icon(MingCute.music_2_fill),
            label: Text(l10n.navLocal),
          ),
          NavigationRailDestination(
            icon: const Icon(MingCute.folder_download_fill),
            label: Text(l10n.navOffline),
          ),
        ],
        selectedIndex: navigationShell.currentIndex,
        minWidth: 70,
        onDestinationSelected: navigationShell.goBranch,
        groupAlignment: 0.0,
        unselectedIconTheme:
            const IconThemeData(color: AppTheme.primaryColor2, size: 22),
        selectedIconTheme:
            const IconThemeData(color: AppTheme.primaryColor1, size: 22),
        indicatorColor: AppTheme.accentViolet.withValues(alpha: 0.22),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class HorizontalNavBar extends StatelessWidget {
  const HorizontalNavBar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.surfaceBorderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: GNav(
        gap: 6.0,
        tabBackgroundColor: AppTheme.accentViolet.withValues(alpha: 0.18),
        color: AppTheme.primaryColor2,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        activeColor: AppTheme.accentViolet,
        textStyle: AppTheme.secondoryTextStyleMedium.copyWith(
          color: AppTheme.primaryColor1,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: Colors.transparent,
        tabs: [
          GButton(icon: MingCute.home_4_fill, text: l10n.navHome),
          GButton(icon: MingCute.book_5_fill, text: l10n.navLibrary),
          GButton(icon: MingCute.search_2_fill, text: l10n.navSearch),
          GButton(icon: MingCute.music_2_fill, text: l10n.navLocal),
          GButton(icon: MingCute.folder_download_fill, text: l10n.navOffline),
        ],
        selectedIndex: navigationShell.currentIndex,
        onTabChange: navigationShell.goBranch,
      ),
    );
  }
}
