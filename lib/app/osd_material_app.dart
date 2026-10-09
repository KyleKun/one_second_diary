import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:one_second_diary/app/platform_reduced_motion.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_text_scale_clamp.dart';
import 'package:one_second_diary/theme/osd_theme.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The `MaterialApp` of every app root, below `OsdLocalizationRoot`: the
/// locale and delegates from easy_localization (so Material widgets are
/// translated too), the themes with the typography of the app language and
/// the user's Bold Text setting, the theme animation, and the root text
/// scale clamp. Under reduced motion (either platform setting:
/// [PlatformReducedMotion]) the themes make every page push and pop a
/// 150 ms crossfade. Bold Text reaches text only through the typography:
/// below this widget `MediaQuery.boldText` is false, so Flutter does not
/// force 700 on every `Text` and field.
///
/// Every root shows its pages through a router ([routerConfig]): the app's,
/// or the launch error state's one-page router.
class OsdMaterialApp extends StatelessWidget {
  /// [builder] wraps the router's navigator, inside the text scale clamp
  /// (app-wide listeners go there).
  const OsdMaterialApp({
    super.key,
    required this.darkMode,
    required this.routerConfig,
    this.builder,
    this.animateTheme = true,
    this.legacyStampFont = false,
  });

  final bool darkMode;

  /// The "legacy font" preference, which the stamp previews follow.
  final bool legacyStampFont;

  /// False while the theme reveal shows a theme change: the theme then
  /// changes at once under the reveal's picture instead of crossfading.
  final bool animateTheme;
  final RouterConfig<Object> routerConfig;
  final TransitionBuilder? builder;

  // iOS Reduce Motion counts as reduced motion from here down, for the
  // themes' transitions too.
  @override
  Widget build(BuildContext context) => PlatformReducedMotion(
    child: _OsdMaterialApp(
      darkMode: darkMode,
      routerConfig: routerConfig,
      builder: builder,
      animateTheme: animateTheme,
      legacyStampFont: legacyStampFont,
    ),
  );
}

class _OsdMaterialApp extends StatelessWidget {
  const _OsdMaterialApp({
    required this.darkMode,
    required this.routerConfig,
    required this.builder,
    required this.animateTheme,
    required this.legacyStampFont,
  });

  final bool darkMode;
  final bool animateTheme;
  final bool legacyStampFont;
  final RouterConfig<Object> routerConfig;
  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final OsdTypography typography = OsdTypography.forLocale(
      context.locale,
      boldText: MediaQuery.boldTextOf(context),
      legacyStampFont: legacyStampFont,
    );
    final bool reducedMotion = OsdMotion.reduced(context);
    return MaterialApp.router(
      routerConfig: routerConfig,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: OsdTheme.light(
        typography: typography,
        reducedMotion: reducedMotion,
      ),
      darkTheme: OsdTheme.dark(
        typography: typography,
        reducedMotion: reducedMotion,
      ),
      // The app never follows the phone's theme after the first launch.
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: animateTheme
          ? OsdMotion.d(context, OsdTheme.animationDuration)
          : Duration.zero,
      themeAnimationCurve: OsdTheme.animationCurve,
      // The typography already applies Bold Text (+100, capped at 700).
      // Below the app, `MediaQuery.boldText` is off,
      // or `Text` and `EditableText` would force every weight to 700. The
      // app builder gets a context below both overrides.
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(boldText: false),
        child: OsdTextScaleClamp(
          role: OsdTextScaleRole.root,
          child: Builder(
            builder: (BuildContext context) =>
                builder?.call(context, child) ??
                child ??
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
