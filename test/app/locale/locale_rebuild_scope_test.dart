import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/app/locale/locale_rebuild_scope.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';

/// Reads a string the way every widget does: through `Strings`, which adds
/// no dependency on the locale.
class _Probe extends StatefulWidget {
  const _Probe();

  static const Key textKey = Key('probe.text');

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int taps = 0;

  @override
  Widget build(BuildContext context) =>
      Text('${Strings.language} $taps', key: _Probe.textKey);
}

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableLevels = [];
  });

  tearDown(rootBundle.clear);

  late List<String> applied;

  // As in the app: the page comes from a go_router builder, so nothing
  // above it rebuilds it with a new widget.
  Future<void> pump(WidgetTester tester) async {
    applied = <String>[];
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const _Probe(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      OsdLocalizationRoot(
        language: AppLanguage.en,
        child: Builder(
          builder: (BuildContext context) => MaterialApp.router(
            routerConfig: router,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            builder: (BuildContext context, Widget? child) =>
                LocaleRebuildScope(
                  onLocaleApplied: () => applied.add(Strings.language),
                  child: child!,
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // From the app's context: calling it from the probe's own context would
  // make the probe depend on the locale.
  void changeLanguage(WidgetTester tester, Locale locale) =>
      unawaited(tester.element(find.byType(MaterialApp)).setLocale(locale));

  String textOf(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(_Probe.textKey)).data!;

  testWidgets('a language change rebuilds the widgets in place: they show '
      'the new text and keep their state', (WidgetTester tester) async {
    await pump(tester);
    final _ProbeState probe = tester.state<_ProbeState>(find.byType(_Probe));
    probe.taps = 3;

    changeLanguage(tester, const Locale('de'));
    await tester.pumpAndSettle();

    expect(textOf(tester), 'Sprache 3');
    expect(tester.state(find.byType(_Probe)), same(probe));
  });

  testWidgets('says when each language is applied, the first one '
      'included', (WidgetTester tester) async {
    await pump(tester);
    // The first one once its translations are loaded.
    expect(applied, <String>['Language']);

    changeLanguage(tester, const Locale('de'));
    await tester.pumpAndSettle();

    // Strings already reads German when the callback runs.
    expect(applied, <String>['Language', 'Sprache']);
  });
}
