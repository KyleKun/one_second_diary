import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/app/osd_material_app.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_page_transitions.dart';
import 'package:one_second_diary/theme/osd_theme.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

import '../shared/widgets/support/osd_widget_harness.dart';

/// Text in the app's typography: body 15/400, a 15/600 row title, a
/// display title and a 16/400 field.
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) {
    final OsdTypography typography = context.typography;
    return Material(
      child: Column(
        children: <Widget>[
          Text('body', style: typography.body15),
          Text('row', style: typography.rowTitleStrong),
          Text('title', style: typography.title30),
          TextField(style: typography.field),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableLevels = [];
  });

  tearDown(rootBundle.clear);

  const Key pageKey = Key('page');

  GoRouter onePage(Widget page) {
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => page,
        ),
      ],
    );
    addTearDown(router.dispose);
    return router;
  }

  /// Mounts the app root in [language] over one page, and returns that
  /// page's context.
  Future<BuildContext> pumpApp(
    WidgetTester tester, {
    AppLanguage language = AppLanguage.en,
  }) async {
    await tester.pumpWidget(
      OsdLocalizationRoot(
        language: language,
        child: OsdMaterialApp(
          darkMode: true,
          routerConfig: onePage(const SizedBox(key: pageKey)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.element(find.byKey(pageKey));
  }

  void phoneAsks(WidgetTester tester, FakeAccessibilityFeatures features) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = features;
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  group('text scale', () {
    for (final (double phone, double page) in <(double, double)>[
      (1.5, 1.5),
      (3, 2),
    ]) {
      testWidgets('the phone at $phone reaches the pages at $page', (
        WidgetTester tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = phone;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final BuildContext context = await pumpApp(tester);

        expect(MediaQuery.textScalerOf(context).scale(10), 10 * page);
      });
    }

    testWidgets('pages and the app builder see the root text scale clamp '
        '(2.0) and no Bold Text', (WidgetTester tester) async {
      tester.platformDispatcher
        ..textScaleFactorTestValue = 3
        ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          boldText: true,
        );
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      late MediaQueryData inBuilder;

      await tester.pumpWidget(
        OsdLocalizationRoot(
          language: AppLanguage.en,
          child: OsdMaterialApp(
            darkMode: true,
            routerConfig: onePage(const SizedBox(key: pageKey)),
            builder: (BuildContext context, Widget? child) {
              inBuilder = MediaQuery.of(context);
              return child!;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final MediaQueryData inPage = MediaQuery.of(
        tester.element(find.byKey(pageKey)),
      );
      for (final MediaQueryData data in <MediaQueryData>[inBuilder, inPage]) {
        expect(data.textScaler.scale(10), 20);
        expect(data.boldText, isFalse);
      }
    });
  });

  group('typography', () {
    testWidgets('Bold Text makes Rubik heavier', (WidgetTester tester) async {
      phoneAsks(tester, const FakeAccessibilityFeatures(boldText: true));

      final OsdTypography typography = OsdTypography.of(await pumpApp(tester));

      expect(typography.boldText, isTrue);
      expect(typography.body14Loose.fontWeight, FontWeight.w500);
    });

    testWidgets('without Bold Text, the drawn weights', (
      WidgetTester tester,
    ) async {
      final OsdTypography typography = OsdTypography.of(await pumpApp(tester));

      expect(typography.boldText, isFalse);
      expect(typography.body14Loose.fontWeight, FontWeight.w400);
    });

    // With the platform's Bold Text on, Rubik weights go up by 100 (capped at
    // 700). Flutter would also force every Text and EditableText to bold on
    // its own.
    testWidgets('Bold Text raises Rubik by 100 and nothing else: no forced '
        'bold on text or fields', (WidgetTester tester) async {
      phoneAsks(tester, const FakeAccessibilityFeatures(boldText: true));

      await tester.pumpWidget(
        OsdLocalizationRoot(
          language: AppLanguage.en,
          child: OsdMaterialApp(
            darkMode: true,
            routerConfig: onePage(const _Probe()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FontWeight? painted(String text) => tester
          .renderObject<RenderParagraph>(find.text(text))
          .text
          .style
          ?.fontWeight;
      expect(painted('body'), FontWeight.w500);
      expect(painted('row'), FontWeight.w700);
      expect(painted('title'), FontWeight.w700);
      final EditableTextState field = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(field.renderEditable.text!.style!.fontWeight, FontWeight.w500);
    });
  });

  group('theme animation', () {
    MaterialApp app(WidgetTester tester) =>
        tester.widget<MaterialApp>(find.byType(MaterialApp));

    testWidgets('the theme change animates as drawn', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      expect(app(tester).themeAnimationDuration, OsdTheme.animationDuration);
    });

    testWidgets('reduced motion makes it a 150 ms crossfade', (
      WidgetTester tester,
    ) async {
      phoneAsks(
        tester,
        const FakeAccessibilityFeatures(disableAnimations: true),
      );

      await pumpApp(tester);

      expect(
        app(tester).themeAnimationDuration,
        const Duration(milliseconds: 150),
      );
    });
  });

  // The router's pages (`OsdPages`) take their transition from the app theme
  // when they are pushed.
  testWidgets('under reduced motion a pushed page crossfades in 150 ms '
      'without moving', (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const Key next = Key('next');
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              OsdPages.material(state, const SizedBox.expand()),
        ),
        GoRoute(
          path: '/next',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              OsdPages.material(state, const SizedBox.expand(key: next)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(
          tester.view,
        ).copyWith(disableAnimations: true),
        child: OsdLocalizationRoot(
          language: AppLanguage.en,
          child: OsdMaterialApp(darkMode: true, routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder page = find.byKey(next);
    router.push<void>('/next').ignore();
    await tester.pump();
    await tester.pump();
    final Animation<double> transition = ModalRoute.of(
      tester.element(page),
    )!.animation!;
    for (final (int ms, double value) in <(int, double)>[(75, .5), (75, 1)]) {
      await tester.pump(Duration(milliseconds: ms));
      expect(transition.value, closeTo(value, .01));
      expect(
        tester.getRect(page),
        const Rect.fromLTWH(0, 0, 390, 844),
        reason: 'no slide or zoom',
      );
      expect(opacityOf(tester, page), closeTo(value, .01));
    }
  });

  // Flutter 3.47 reports iOS Reduce Motion as `reduceMotion`, not
  // `disableAnimations`, so the root folds it in once for the whole app
  // (OsdMotion, the page transitions, every widget that honours
  // `MediaQuery.disableAnimationsOf`).
  group('iOS Reduce Motion', () {
    testWidgets('reaches the pages as disableAnimations, with the reduced '
        'transitions and theme change', (WidgetTester tester) async {
      phoneAsks(tester, const FakeAccessibilityFeatures(reduceMotion: true));

      final BuildContext page = await pumpApp(tester);

      expect(MediaQuery.disableAnimationsOf(page), isTrue);
      expect(OsdMotion.reduced(page), isTrue);
      expect(
        Theme.of(page).pageTransitionsTheme,
        OsdPageTransitions.reducedMotion,
      );
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .themeAnimationDuration,
        const Duration(milliseconds: 150),
      );
    });

    testWidgets('is followed when the phone changes it, and the pages keep '
        'their state', (WidgetTester tester) async {
      final BuildContext page = await pumpApp(tester);
      expect(MediaQuery.disableAnimationsOf(page), isFalse);

      phoneAsks(tester, const FakeAccessibilityFeatures(reduceMotion: true));
      await tester.pump();
      expect(tester.element(find.byKey(pageKey)), same(page));
      expect(MediaQuery.disableAnimationsOf(page), isTrue);
      // The themes swap through the 150 ms theme crossfade.
      await tester.pump(OsdMotion.reducedMax);
      expect(
        Theme.of(page).pageTransitionsTheme,
        OsdPageTransitions.reducedMotion,
      );

      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      expect(tester.element(find.byKey(pageKey)), same(page));
      expect(MediaQuery.disableAnimationsOf(page), isFalse);
    });

    testWidgets("Android's remove animations still counts on its own", (
      WidgetTester tester,
    ) async {
      phoneAsks(
        tester,
        const FakeAccessibilityFeatures(disableAnimations: true),
      );

      final BuildContext page = await pumpApp(tester);

      expect(MediaQuery.disableAnimationsOf(page), isTrue);
    });
  });
}
