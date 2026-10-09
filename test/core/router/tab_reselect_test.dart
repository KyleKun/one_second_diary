import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/app_shell.dart';
import 'package:one_second_diary/core/router/tab_reselect_listener.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_bottom_nav.dart';
import 'package:one_second_diary/theme/osd_theme.dart';

import '../../shared/harness/settle.dart';

const List<AppRoute> _tabs = <AppRoute>[
  AppRoute.today,
  AppRoute.diary,
  AppRoute.journey,
  AppRoute.settings,
];

void main() {
  setUpAll(() => EasyLocalization.logger.enableLevels = []);

  late List<AppRoute> reselected;
  late ScrollController diaryScroll;

  Future<void> pumpShell(WidgetTester tester) async {
    diaryScroll = ScrollController();
    addTearDown(diaryScroll.dispose);
    reselected = <AppRoute>[];
    final GoRouter router = GoRouter(
      initialLocation: AppRoute.today.path,
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder:
              (
                BuildContext context,
                GoRouterState state,
                StatefulNavigationShell shell,
              ) => AppShell(navigationShell: shell),
          branches: <StatefulShellBranch>[
            for (final AppRoute tab in _tabs)
              StatefulShellBranch(
                routes: <RouteBase>[
                  GoRoute(
                    path: tab.path,
                    builder: (BuildContext context, GoRouterState state) =>
                        TabReselectListener(
                          tab: tab,
                          onReselect: () => reselected.add(tab),
                          scrollController: tab == AppRoute.diary
                              ? diaryScroll
                              : null,
                          child: tab == AppRoute.diary
                              ? ListView.builder(
                                  controller: diaryScroll,
                                  itemExtent: 100,
                                  itemCount: 100,
                                  itemBuilder:
                                      (BuildContext context, int index) =>
                                          Text('$index'),
                                )
                              : Text(tab.name),
                        ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: OsdTheme.dark(), routerConfig: router),
    );
    await settle(tester);
  }

  Future<void> tapTab(WidgetTester tester, AppRoute tab) async {
    await tester.tap(find.byKey(OsdBottomNav.itemKey(_tabs.indexOf(tab))));
    await settle(tester);
  }

  testWidgets('tapping the tab already shown signals its pages, which scroll '
      'back to their start; switching tabs signals nothing', (tester) async {
    await pumpShell(tester);

    await tapTab(tester, AppRoute.diary);
    expect(reselected, isEmpty);
    diaryScroll.jumpTo(3000);

    await tapTab(tester, AppRoute.diary);

    expect(reselected, <AppRoute>[AppRoute.diary]);
    expect(diaryScroll.offset, 0);
  });
}
