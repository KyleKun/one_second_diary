import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_fonts.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_page_transitions.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_tints.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The app's [ThemeData], built in one place.
///
/// Custom widgets read `OsdColors` and `OsdTypography` from the theme's
/// extensions. The Material `ColorScheme` and component themes exist so stock
/// widgets (pickers, `LicensePage`, dialogs, tooltips, progress indicators,
/// `showTimePicker`) match the design without further work.
///
/// ```dart
/// MaterialApp(
///   theme: OsdTheme.light(typography: typography),
///   darkTheme: OsdTheme.dark(typography: typography),
///   themeAnimationDuration: OsdTheme.animationDuration,
///   themeAnimationCurve: OsdTheme.animationCurve,
/// )
/// ```
///
/// Each theme is built once per typography and reduced-motion setting and
/// reused.
///
/// [dark] and [light] take `reducedMotion` (`OsdMotion.reduced`, read above
/// the `MaterialApp`): page routes then crossfade in 150 ms instead of the
/// platform transition (`OsdPageTransitions`).
abstract final class OsdTheme {
  /// The light ↔ dark crossfade. Reduced motion makes it 150 ms.
  static const Duration animationDuration = OsdMotion.themeChange;
  static const Curve animationCurve = OsdMotion.themeChangeCurve;

  // A memo of a pure function over a handful of keys (two brightnesses × the
  // locales, Bold Text and reduced-motion settings seen), not app state.
  // `ThemeData` captures `defaultTargetPlatform`, so the platform is part of
  // the key.
  static final Map<_Key, ThemeData> _built = <_Key, ThemeData>{};

  /// The dark theme, the design's source of truth.
  static ThemeData dark({
    OsdTypography typography = const OsdTypography(),
    bool reducedMotion = false,
  }) => _memo(Brightness.dark, typography, reducedMotion: reducedMotion);

  static ThemeData light({
    OsdTypography typography = const OsdTypography(),
    bool reducedMotion = false,
  }) => _memo(Brightness.light, typography, reducedMotion: reducedMotion);

  static ThemeData _memo(
    Brightness brightness,
    OsdTypography typography, {
    required bool reducedMotion,
  }) => _built.putIfAbsent(
    (brightness, typography, reducedMotion, defaultTargetPlatform),
    () => _build(
      brightness == Brightness.dark ? OsdColors.dark : OsdColors.light,
      typography,
      brightness,
      reducedMotion: reducedMotion,
    ),
  );

  /// System bar colours for a page on a theme surface: a transparent status bar
  /// and a BG navigation bar, with icons that contrast. Shell tabs too: the
  /// bottom nav floats on BG.
  /// Apply them with `AnnotatedRegion<SystemUiOverlayStyle>`.
  static SystemUiOverlayStyle systemBars(Brightness brightness) {
    final colors = brightness == Brightness.dark
        ? OsdColors.dark
        : OsdColors.light;
    final icons = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: icons,
      statusBarBrightness: brightness,
      systemNavigationBarColor: colors.bg,
      systemNavigationBarIconBrightness: icons,
      systemNavigationBarDividerColor: const Color(0x00000000),
    );
  }

  /// Material text geometry without sizes or line heights: only the baseline
  /// every slot needs (input decorators read it).
  static TextTheme _geometry(TextBaseline baseline) {
    final style = TextStyle(textBaseline: baseline);
    return TextTheme(
      displayLarge: style,
      displayMedium: style,
      displaySmall: style,
      headlineLarge: style,
      headlineMedium: style,
      headlineSmall: style,
      titleLarge: style,
      titleMedium: style,
      titleSmall: style,
      bodyLarge: style,
      bodyMedium: style,
      bodySmall: style,
      labelLarge: style,
      labelMedium: style,
      labelSmall: style,
    );
  }

  static ThemeData _build(
    OsdColors c,
    OsdTypography t,
    Brightness brightness, {
    required bool reducedMotion,
  }) {
    const transparent = Color(0x00000000);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.co,
      onPrimary: c.onCo,
      primaryContainer: Color.alphaBlend(OsdTints.coTint14, c.bg),
      onPrimaryContainer: c.coInk,
      secondary: c.tx,
      onSecondary: c.bg,
      secondaryContainer: c.off,
      onSecondaryContainer: c.tx,
      tertiary: c.purple,
      onTertiary: const Color(0xFFFFFFFF),
      error: c.red,
      onError: c.bg,
      errorContainer: Color.alphaBlend(OsdTints.redTint12, c.bg),
      onErrorContainer: c.red,
      surface: c.bg,
      onSurface: c.tx,
      onSurfaceVariant: c.mu,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.card,
      surfaceContainer: c.nav,
      surfaceContainerHigh: c.sh,
      surfaceContainerHighest: c.c2,
      surfaceDim: c.bg,
      surfaceBright: c.card,
      outline: c.fa,
      outlineVariant: c.ln,
      shadow: const Color(0xFF000000),
      scrim: c.dim,
      inverseSurface: c.snackbarBg,
      onInverseSurface: c.snackbarText,
      inversePrimary: c.snackbarText,
      surfaceTint: transparent,
    );
    final fieldRadius = BorderRadius.circular(OsdRadius.r16);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: OsdFonts.rubik,
      // Every role has an explicit height or none, and none means the font's
      // own "normal" line height (CSS `line-height: normal`). Material's
      // text geometry would give every such style 1.43 once `Theme.of`
      // localises the theme, so the geometry only keeps the baselines.
      typography: Typography.material2021(
        platform: defaultTargetPlatform,
        colorScheme: scheme,
        englishLike: _geometry(TextBaseline.alphabetic),
        dense: _geometry(TextBaseline.ideographic),
        tall: _geometry(TextBaseline.alphabetic),
      ),
      textTheme: t.materialTextTheme(c),
      extensions: <ThemeExtension<dynamic>>[c, t],
      // Flat design: press feedback is a scale, never a ripple.
      splashFactory: NoSplash.splashFactory,
      splashColor: transparent,
      highlightColor: c.sel,
      hoverColor: c.sel,
      focusColor: c.sel,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconTheme: IconThemeData(
        size: OsdSizes.iconDefault,
        color: c.tx,
        fill: 0,
        weight: 400,
        grade: 0,
        opticalSize: 24,
      ),
      dividerTheme: DividerThemeData(color: c.ln, thickness: 1, space: 1),
      // Stock pages (the licences) draw the OSD back glyph, as every
      // `OsdAppBar` does (Material Symbols Rounded only).
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (BuildContext context) => const Icon(
          OsdIcons.arrowBack,
          size: OsdSizes.iconDefault,
          fill: 0,
          weight: 400,
          grade: 0,
          opticalSize: OsdSizes.iconDefault,
          applyTextScaling: false,
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: c.bg,
        foregroundColor: c.tx,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: transparent,
        toolbarHeight: OsdSizes.appBarHeight,
        centerTitle: false,
        titleSpacing: 6,
        titleTextStyle: t.appBarTitle.copyWith(color: c.tx),
        systemOverlayStyle: systemBars(brightness),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.sh,
        modalBackgroundColor: c.sh,
        surfaceTintColor: transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        dragHandleColor: c.handle,
        dragHandleSize: OsdSizes.sheetHandleSize,
        modalBarrierColor: c.scrimModal,
        constraints: const BoxConstraints(maxWidth: OsdSizes.sheetMaxWidth),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(OsdRadius.r28),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.sh,
        surfaceTintColor: transparent,
        elevation: 0,
        barrierColor: c.scrimModal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OsdRadius.r28),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        titleTextStyle: t.sheetTitle.copyWith(color: c.tx),
        contentTextStyle: t.body14Loose.copyWith(color: c.mu),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.snackbarBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OsdRadius.r18),
        ),
        contentTextStyle: t.titleSmall.copyWith(color: c.snackbarText),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.tx,
        linearTrackColor: c.off,
        circularTrackColor: transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.co,
        selectionColor: c.co.withValues(alpha: .25),
        selectionHandleColor: c.co,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.c2,
        hintStyle: t.field.copyWith(color: c.mu),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: c.tx, width: 1.5),
        ),
      ),
      // Fallbacks only: the app draws its own OsdSwitch, radios and checks.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.bg : c.mu,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.tx : c.off,
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.tx : c.fa,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.tx : transparent,
        ),
        checkColor: WidgetStatePropertyAll<Color>(c.bg),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.snackbarBg,
          borderRadius: BorderRadius.circular(OsdRadius.r10),
        ),
        textStyle: t.label13.copyWith(color: c.snackbarText),
      ),
      pageTransitionsTheme: reducedMotion
          ? OsdPageTransitions.reducedMotion
          : OsdPageTransitions.platform,
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: c.co,
        textTheme: CupertinoTextThemeData(
          textStyle: t.field.copyWith(color: c.tx),
          dateTimePickerTextStyle: t.pickerText.copyWith(color: c.tx),
        ),
      ),
    );
  }
}

typedef _Key = (Brightness, OsdTypography, bool, TargetPlatform);
