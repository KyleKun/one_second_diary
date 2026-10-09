import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_bottom_nav.dart';

import '../harness/settle.dart';

/// Drives the app's navigation: the four tabs, pushed routes and the
/// system back button, and says where the app is.
class ShellRobot {
  ShellRobot(this.tester, {required this.router});

  final WidgetTester tester;
  final GoRouter router;

  /// The tabs, in nav order.
  static const List<AppRoute> tabs = <AppRoute>[
    AppRoute.today,
    AppRoute.diary,
    AppRoute.journey,
    AppRoute.settings,
  ];

  /// The location of the top route (a pushed one included).
  String get location => router.state.uri.toString();

  /// A context below the router, as a page has.
  BuildContext get _pageContext =>
      router.routerDelegate.navigatorKey.currentContext!;

  Future<void> tapTab(AppRoute tab) async {
    await tester.tap(find.byKey(OsdBottomNav.itemKey(tabs.indexOf(tab))));
    await settle(tester);
  }

  /// Pushes [route], which takes no arguments, the way a page does
  /// (`AppRoute.push`). Throws what the push throws.
  Future<void> push(AppRoute route) async {
    route.push<Object?>(_pageContext).ignore();
    await settle(tester);
  }

  /// Opens the route of [args] with them, the way a page does
  /// (`RouteArgs.push`).
  Future<void> open(RouteArgs args) async {
    args.push<Object?>(_pageContext).ignore();
    await settle(tester);
  }

  /// Opens the route of [args] the way a page does (`RouteArgs.push<T>`)
  /// and returns what it will pop with, once it has.
  Future<RouteResult<T>> openForResult<T extends Object?>(
    RouteArgs args,
  ) async {
    final RouteResult<T> result = RouteResult<T>(args.push<T>(_pageContext));
    await settle(tester);
    return result;
  }

  /// Replaces the top route with the route of [args], the way a page hands
  /// over to the next one (`RouteArgs.pushReplacement`: the camera to the
  /// clip editor); what the new route pops with goes to whoever opened the
  /// replaced one.
  Future<void> replaceTopWith(RouteArgs args) async {
    args.pushReplacement<Object?>(_pageContext).ignore();
    await settle(tester);
  }

  /// Pops the top route with [result], the way its page closes.
  Future<void> popWith(Object? result) async {
    router.pop(result);
    await settle(tester);
  }

  /// Goes to [route] the way a page does (`AppRoute.go`).
  Future<void> go(AppRoute route) async {
    route.go(_pageContext);
    await settle(tester);
  }

  /// Presses the system back button. Returns false when the app would exit
  /// (the system then closes it).
  Future<bool> pressBack() async {
    final bool handled = await tester.binding.handlePopRoute();
    await settle(tester);
    return handled;
  }

  /// Goes to [route] with [extra], as a deep link or a restored location
  /// would carry it (never how a page opens a route).
  Future<void> goWithExtra(AppRoute route, Object? extra) async {
    router.go(route.path, extra: extra);
    await settle(tester);
  }

  void expectAt(AppRoute route) => expect(router.state.uri.path, route.path);

  /// The top route was opened with [args].
  void expectOpenedWith(RouteArgs args) {
    expectAt(args.route);
    expect(router.state.extra, args);
  }

  /// [route]'s page is drawn (its root is keyed `ValueKey<AppRoute>`).
  void expectShown(AppRoute route) => expect(_pageOf(route), findsOneWidget);

  /// No page of [route] exists, shown or not.
  void expectNoPageOf(AppRoute route) =>
      expect(_pageOf(route, skipOffstage: false), findsNothing);

  /// Whether the shell (tabs and nav) is the top route.
  void expectNavVisible({required bool visible}) => expect(
    find.byKey(OsdBottomNav.barKey).hitTestable(),
    visible ? findsOneWidget : findsNothing,
  );

  /// Whether [tab] is the nav's active item.
  void expectActiveTab(AppRoute tab) => expect(
    tester.widget<OsdBottomNav>(find.byType(OsdBottomNav)).index,
    tabs.indexOf(tab),
  );

  /// The nav's labels, in order.
  void expectNavLabels(List<String> labels) => expect(
    tester
        .widget<OsdBottomNav>(find.byType(OsdBottomNav))
        .destinations
        .map((OsdNavDestination destination) => destination.label),
    labels,
  );

  /// The page of [route] (the tab or the pushed page) shows [title].
  void expectPageTitle(AppRoute route, String title) => expect(
    find.descendant(of: _pageOf(route), matching: find.text(title)),
    findsOneWidget,
  );

  /// The top page's back button says [tooltip].
  void expectBackTooltip(String tooltip) =>
      expect(find.byTooltip(tooltip).hitTestable(), findsOneWidget);

  /// [route]'s page exists once, shown or not: no copy of it was pushed
  /// into another tab.
  void expectOnePageOf(AppRoute route) =>
      expect(_pageOf(route, skipOffstage: false), findsOneWidget);

  /// The element of [route]'s page, to tell whether it was kept or built
  /// again.
  Element pageElement(AppRoute route) =>
      tester.element(_pageOf(route, skipOffstage: false));

  /// Whether the page of [route] is kept alive but not drawn, with its
  /// animations stopped.
  void expectHiddenAndStill(AppRoute route) {
    expect(_pageOf(route), findsNothing);
    expect(TickerMode.valuesOf(pageElement(route)).enabled, isFalse);
  }

  Finder _pageOf(AppRoute route, {bool skipOffstage = true}) =>
      find.byKey(ValueKey<AppRoute>(route), skipOffstage: skipOffstage);
}

/// What a route opened by [ShellRobot.openForResult] popped with. Never
/// awaited: a route that never pops fails the test instead of hanging it.
final class RouteResult<T extends Object?> {
  RouteResult(Future<T?> future) {
    future.then((T? value) {
      _value = value;
      _popped = true;
    }).ignore();
  }

  bool _popped = false;
  T? _value;

  /// Whether the route (or the route it handed over to) popped.
  bool get popped => _popped;

  /// What it popped with. Fails the test while it has not popped.
  T? get value {
    expect(_popped, isTrue, reason: 'the route has not popped yet');
    return _value;
  }
}
