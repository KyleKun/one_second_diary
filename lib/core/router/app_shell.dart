import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/tab_reselect_scope.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_bottom_nav.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_theme.dart';

/// The four-tab shell: the active tab under the floating `OsdBottomNav`, inside the
/// snackbar host (the nav anchors snackbars 14 above itself), with the
/// shell's system bar colours.
///
/// Tapping another tab shows it as it was left; tapping the active tab
/// again returns it to its first page and tells its pages
/// (`TabReselectListener`: scroll back to the start). Android back first
/// pops what the tab or the root navigator shows, then goes from another
/// tab to Today, and on Today leaves the app. `PopScope` tells the system
/// ahead of time, so the predictive back gesture shows the right
/// destination.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  /// The tab of Today, where back leaves the app.
  static const int todayIndex = 0;

  /// The tabs, in nav (branch) order.
  static const List<AppRoute> tabs = <AppRoute>[
    AppRoute.today,
    AppRoute.diary,
    AppRoute.journey,
    AppRoute.settings,
  ];

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final TabReselects _reselects = TabReselects();

  @override
  void dispose() {
    _reselects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StatefulNavigationShell navigationShell = widget.navigationShell;
    return PopScope<Object?>(
      canPop: navigationShell.currentIndex == AppShell.todayIndex,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) navigationShell.goBranch(AppShell.todayIndex);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: OsdTheme.systemBars(Theme.of(context).brightness),
        child: Scaffold(
          body: TabReselectScope(
            reselects: _reselects,
            child: OsdSnackbarHost(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: _UnderNav(child: navigationShell)),
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    child: _ShellNav(
                      navigationShell: navigationShell,
                      reselects: _reselects,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tabs run under the floating nav: their bottom padding is the nav's
/// height, so a tab ends its scrolling content above it while the capsule's
/// surroundings show the tab.
class _UnderNav extends StatelessWidget {
  const _UnderNav({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double nav = OsdSizes.navHeight(
      bottomInset: media.viewPadding.bottom,
    );
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(bottom: nav),
        viewPadding: media.viewPadding.copyWith(bottom: nav),
      ),
      child: child,
    );
  }
}

/// The nav, below the snackbar host so a tab switch can hide the snackbar.
class _ShellNav extends StatelessWidget {
  const _ShellNav({required this.navigationShell, required this.reselects});

  final StatefulNavigationShell navigationShell;
  final TabReselects reselects;

  @override
  Widget build(BuildContext context) {
    final int index = navigationShell.currentIndex;
    return OsdBottomNav(
      destinations: <OsdNavDestination>[
        OsdNavDestination(
          icon: OsdIcons.radioButtonChecked,
          label: CommonLabels.of(context).today,
        ),
        OsdNavDestination(icon: OsdIcons.autoStories, label: Strings.diary),
        OsdNavDestination(icon: OsdIcons.movie, label: Strings.journey),
        OsdNavDestination(icon: OsdIcons.settings, label: Strings.settings),
      ],
      index: index,
      onSelect: (int tab) {
        OsdSnackbar.hide(context);
        navigationShell.goBranch(tab);
      },
      onReselect: () {
        navigationShell.goBranch(index, initialLocation: true);
        reselects.reselect(AppShell.tabs[index]);
      },
    );
  }
}
