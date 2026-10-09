import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/theme/osd_theme.dart';

import '../../../shared/harness/settle.dart';
import '../../../shared/widgets/support/osd_widget_harness.dart';

/// Pumps [child] (or, with [router], the router's pages) as a page of the
/// app: the real translations in
/// [language] (`OsdLocalizationRoot`), the OSD theme, and the device
/// settings the design reacts to, on a [size] screen at DPR 3; [above]
/// wraps the whole app, as the app root provides its app-scoped cubits
/// (sheets and dialogs sit above the page). Then waits
/// for the translations and lets the page [settle].
///
/// For page tests that need real text (plurals, the stat value split)
/// without launching the app; journeys use `AppRobot`. Clears the asset
/// cache after the test (translations are loaded through `rootBundle`).
Future<void> pumpLocalizedOsd(
  WidgetTester tester,
  Widget child, {
  GoRouter? router,
  AppLanguage language = AppLanguage.en,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  bool disableAnimations = false,
  Size size = kOsdFrame,
  bool settleAfter = true,
  Widget Function(Widget app)? above,
}) async {
  EasyLocalization.logger.enableLevels = [];
  addTearDown(rootBundle.clear);
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final Widget Function(Widget app) wrap = above ?? (Widget app) => app;
  await tester.pumpWidget(
    wrap(
      OsdLocalizationRoot(
        language: language,
        child: Builder(
          builder: (BuildContext context) {
            final ThemeMode themeMode = brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light;
            Widget settings(BuildContext context, Widget? navigator) =>
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                    disableAnimations: disableAnimations,
                  ),
                  child: navigator!,
                );
            return router == null
                ? MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: OsdTheme.light(),
                    darkTheme: OsdTheme.dark(),
                    themeMode: themeMode,
                    themeAnimationDuration: Duration.zero,
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    builder: settings,
                    home: child,
                  )
                : MaterialApp.router(
                    debugShowCheckedModeBanner: false,
                    theme: OsdTheme.light(),
                    darkTheme: OsdTheme.dark(),
                    themeMode: themeMode,
                    themeAnimationDuration: Duration.zero,
                    locale: context.locale,
                    supportedLocales: context.supportedLocales,
                    localizationsDelegates: context.localizationDelegates,
                    builder: settings,
                    routerConfig: router,
                  );
          },
        ),
      ),
    ),
  );
  // The translations load through the asset bundle.
  for (int i = 0; i < 5; i++) {
    await tester.pump();
  }
  if (settleAfter) await settle(tester);
}
