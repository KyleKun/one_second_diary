import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/router/app_route.dart';

/// The taps on the tab already shown, as `AppShell` hears them: [last] is
/// the tab tapped again, announced to every listener.
final class TabReselects extends ChangeNotifier {
  AppRoute? _last;

  /// The tab tapped again last; null before any.
  AppRoute? get last => _last;

  /// The user tapped [tab], which was already shown.
  void reselect(AppRoute tab) {
    _last = tab;
    notifyListeners();
  }
}

/// Hands the shell's [TabReselects] to the tab pages below it; they listen
/// through `TabReselectListener`.
class TabReselectScope extends InheritedWidget {
  const TabReselectScope({
    super.key,
    required this.reselects,
    required super.child,
  });

  final TabReselects reselects;

  /// The shell's reselects, or null outside the shell (a pushed page).
  static TabReselects? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabReselectScope>()?.reselects;

  @override
  bool updateShouldNotify(TabReselectScope oldWidget) =>
      reselects != oldWidget.reselects;
}
