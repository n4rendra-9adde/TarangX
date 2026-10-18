import 'package:flutter/material.dart';

/// Canonical TarangX design system and theme tokens.
///
/// Use [AppTheme] or [TarangXTheme] in new code. The [Default_Theme] typedef
/// at the bottom provides 100% backward-compatible access for existing callers.
class AppTheme {
  // ── Brand Identity ──────────────────────────────────────────────────────────
  static const String appName = "TarangX";
  static const String appTagline = "Dark Luxury Music Experience";

  // ── Typography ─────────────────────────────────────────────────────────────
  static const primaryTextStyle = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );
  static const secondoryTextStyle = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );
  static const secondoryTextStyleMedium = TextStyle(
    fontFamily: "Gilroy",
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
  );
  static const tertiaryTextStyle = TextStyle(
    fontFamily: "CodePro",
    letterSpacing: 0.2,
  );
  static const brandTextStyle = TextStyle(
    fontFamily: "Unageo",
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
  );
  static const fontAwesomeRegularFont =
      TextStyle(fontFamily: "FontAwesome-Regular");
  static const fontAwesomeSolidFont =
      TextStyle(fontFamily: "FontAwesome-Solids");

  // ── Dark Luxury Color Palette ───────────────────────────────────────────────
  /// Base background: deep obsidian / near-black charcoal
  static const themeColor = Color(0xFF0B0B0E);

  /// Secondary background for lists and nested surfaces
  static const backgroundSecondary = Color(0xFF101015);

  /// Standard card and sheet surface
  static const surface = Color(0xFF14141B);

  /// Elevated surface for dialogs, menus, and bottom sheets
  static const surfaceElevated = Color(0xFF1A1A23);

  /// Highest elevation surface / active control containers
  static const surfaceContainerHighest = Color(0xFF22222E);

  /// Subtle translucent white outline for glass and card borders
  static const surfaceBorder = Color(0x1FFFFFFF);
  static const surfaceBorderSubtle = Color(0x0EFFFFFF);

  /// Primary text and high-emphasis icons: crisp platinum off-white
  static const primaryColor1 = Color(0xFFF4F4F6);

  /// Secondary text, metadata, and muted icons: refined slate gray
  static const primaryColor2 = Color(0xFFA0A0AB);

  /// Muted caption, timestamp, and inactive text
  static const textMuted = Color(0xFF71717A);

  /// Primary Accent: Electric Violet
  static const accentColor2 = Color(0xFF8B5CF6);
  static const accentViolet = Color(0xFF8B5CF6);

  /// Secondary Accent: Deep Royal Violet
  static const accentColor1 = Color(0xFF6D28D9);
  static const accentIndigo = Color(0xFF6D28D9);

  /// Accent highlight: Soft Lavender / Electric Violet light
  static const accentColor1light = Color(0xFFA78BFA);
  static const accentLavender = Color(0xFFA78BFA);

  /// Glow overlay color
  static const accentGlow = Color(0x338B5CF6);

  /// Semantic feedback colors
  static const successColor = Color(0xFF10B981);
  static const warningColor = Color(0xFFF59E0B);
  static const errorColor = Color(0xFFEF4444);

  // ── Gradients ───────────────────────────────────────────────────────────────
  static const brandGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const violetGradient = LinearGradient(
    colors: [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkSurfaceGradient = LinearGradient(
    colors: [Color(0xFF161620), Color(0xFF101015)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF171722), Color(0xFF121218)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Spacing Tokens ──────────────────────────────────────────────────────────
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;

  // ── Corner Radii ────────────────────────────────────────────────────────────
  static const double radiusSM = 8.0;
  static const double radiusMD = 14.0;
  static const double radiusLG = 20.0;
  static const double radiusPill = 999.0;

  static final BorderRadius cardRadius = BorderRadius.circular(radiusMD);
  static final BorderRadius artworkRadius = BorderRadius.circular(12.0);
  static final BorderRadius dialogRadius = BorderRadius.circular(radiusLG);
  static final BorderRadius sheetRadius =
      const BorderRadius.vertical(top: Radius.circular(24.0));

  // ── Animation Tokens ────────────────────────────────────────────────────────
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 250);
  static const Duration animationSlow = Duration(milliseconds: 400);
  static const Curve animationCurve = Curves.easeOutCubic;

  // ── Theme Data ───────────────────────────────────────────────────────────────
  ThemeData get defaultThemeData {
    const darkScheme = ColorScheme.dark(
      primary: accentColor2,
      secondary: accentColor1,
      surface: surface,
      surfaceContainerHighest: surfaceContainerHighest,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: primaryColor1,
      onSurfaceVariant: primaryColor2,
      outline: surfaceBorder,
      error: errorColor,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: themeColor,
      dialogBackgroundColor: surfaceElevated,
      cardColor: surface,
      primaryColorDark: accentColor2,
      fontFamily: 'Gilroy',
      primarySwatch: MaterialColor(
        accentColor2.value,
        {
          50: accentColor2.withValues(alpha: 0.1),
          100: accentColor2.withValues(alpha: 0.2),
          200: accentColor2.withValues(alpha: 0.3),
          300: accentColor2.withValues(alpha: 0.4),
          400: accentColor2.withValues(alpha: 0.5),
          500: accentColor2.withValues(alpha: 0.6),
          600: accentColor2.withValues(alpha: 0.7),
          700: accentColor2.withValues(alpha: 0.8),
          800: accentColor2.withValues(alpha: 0.9),
          900: accentColor2,
        },
      ),
      colorScheme: darkScheme,
      iconTheme: const IconThemeData(color: primaryColor1),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(accentColor2),
        interactive: true,
        radius: const Radius.circular(10),
        thickness: WidgetStateProperty.all(5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: themeColor,
        foregroundColor: primaryColor1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor1),
        titleTextStyle: TextStyle(
          fontFamily: 'Gilroy',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: primaryColor1,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: accentColor2),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accentColor2,
        selectionColor: Color(0x668B5CF6),
        selectionHandleColor: accentColor2,
      ),
      brightness: Brightness.dark,
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(primaryColor1),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? accentColor2
                : surfaceBorder),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? accentColor2
                : surfaceContainerHighest),
      ),
      searchBarTheme: const SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(surface),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: surfaceElevated,
        textStyle: TextStyle(color: primaryColor1),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surfaceElevated),
        ),
        textStyle: TextStyle(color: primaryColor1),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surfaceElevated),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorderSubtle, width: 1),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accentColor2,
        inactiveTrackColor: surfaceContainerHighest,
        thumbColor: accentColor2,
        overlayColor: accentGlow,
      ),
    );
  }
}

/// Canonical alias for the TarangX design system.
typedef TarangXTheme = AppTheme;

/// Backward-compat alias for [AppTheme].
/// Prefer importing from [core/theme/app_theme.dart] and using [AppTheme] or [TarangXTheme] directly.
// ignore: camel_case_types
typedef Default_Theme = AppTheme;
