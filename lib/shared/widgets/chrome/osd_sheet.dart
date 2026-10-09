import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet_handle.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet_title.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_surface.dart';

/// How tall an [OsdSheet] may grow.
enum OsdSheetHeight {
  /// As tall as its content, up to the screen minus the top inset and 8.
  /// Everything scrolls together.
  content,

  /// Up to the screen minus the top inset and 62. The handle and title stay
  /// fixed and the child (a list) scrolls.
  tall,
}

/// Shows an [OsdSheet] in an [OsdSheetRoute].
///
/// Returns what the sheet pops with. Sheets don't stack: close one before
/// opening the next (pickers and help opened *from* a sheet are the
/// exception).
///
/// [barrierColor] defaults to the modal scrim.
Future<T?> showOsdSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  String? subtitle,
  IconData? titleIcon,
  Color? titleIconColor,
  Widget? titleTrailing,
  bool looseSubtitle = false,
  OsdSheetHeight height = OsdSheetHeight.content,
  bool dismissible = true,
  bool useRootNavigator = true,
  Color? barrierColor,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push<T>(
    OsdSheetRoute<T>(
      colors: context.colors,
      barrierColor: barrierColor,
      reducedMotion: OsdMotion.reduced(context),
      dismissible: dismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (context) => OsdSheet(
        title: title,
        subtitle: subtitle,
        titleIcon: titleIcon,
        titleIconColor: titleIconColor,
        titleTrailing: titleTrailing,
        looseSubtitle: looseSubtitle,
        height: height,
        child: child,
      ),
    ),
  );
}

/// A modal bottom-sheet route: a spring slide-up, a curved exit, and
/// drag-to-dismiss past 25 % of the height or on a fling faster than
/// 700 px/s, while it is the top route (a drag on a sheet already closing
/// does nothing). Under reduced motion it is a crossfade.
///
/// While [busy] (saving) it can't be dragged, tapped away or popped with back.
class OsdSheetRoute<T> extends PopupRoute<T> {
  OsdSheetRoute({
    required this.builder,
    required OsdColors colors,
    required this.reducedMotion,
    this.themes,
    this.dismissible = true,
    this.barrierLabel,
    Color? barrierColor,
    super.settings,
  }) : _barrierColor = barrierColor ?? colors.scrimModal;

  final WidgetBuilder builder;

  final bool reducedMotion;

  /// The themes between the opener and the navigator (a forced-dark camera
  /// keeps its sheets dark).
  final CapturedThemes? themes;

  final bool dismissible;

  final Color _barrierColor;

  @override
  final String? barrierLabel;

  /// Whether the sheet is busy (no dismiss of any kind).
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  /// The slide's curve over the route's animation, made on the first
  /// transition.
  CurvedAnimation? _curved;

  /// The route of the sheet around [context], if any.
  static OsdSheetRoute<dynamic>? of(BuildContext context) {
    final route = ModalRoute.of(context);
    return route is OsdSheetRoute ? route : null;
  }

  /// Marks the sheet around [context] busy (saving) or idle.
  static void setBusy(BuildContext context, {required bool busy}) {
    final route = of(context);
    if (route == null || route.busy.value == busy) return;
    route.busy.value = busy;
    route.changedInternalState();
  }

  bool get _canDismiss => dismissible && !busy.value;

  @override
  Color? get barrierColor => _barrierColor;

  @override
  bool get barrierDismissible => _canDismiss;

  @override
  Curve get barrierCurve => Curves.easeOut;

  @override
  Duration get transitionDuration =>
      reducedMotion ? const Duration(milliseconds: 150) : OsdMotion.emphasized;

  @override
  Duration get reverseTransitionDuration =>
      reducedMotion ? const Duration(milliseconds: 150) : OsdMotion.sheetClose;

  @override
  Simulation? createSimulation({required bool forward}) =>
      forward && !reducedMotion ? _OpenSpring(controller!.value) : null;

  @override
  void dispose() {
    busy.dispose();
    _curved?.dispose();
    super.dispose();
  }

  /// Whether a drag may move or close the sheet: only while it is the top
  /// route. A sheet on its way out (closed a moment ago, still sliding
  /// away) is no longer in the navigator: a drag on it would stop it where
  /// it is, left on screen for good, and its `pop` would close the page
  /// under it instead (the camera, then the app's last page).
  bool get _canDrag => _canDismiss && isCurrent;

  void _dragUpdate(double delta, double height) {
    if (!_canDrag || height <= 0) return;
    controller!.value -= delta / height;
  }

  void _dragEnd(double velocity, double height) {
    if (!_canDrag) return;
    final controller = this.controller!;
    if (velocity > 700 || controller.value < .75) {
      navigator?.pop();
    } else if (!reducedMotion) {
      controller.animateWith(_OpenSpring(controller.value));
    } else {
      controller.forward();
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget page = Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: OsdSizes.sheetMaxWidth),
        child: _SheetFrame(
          route: this,
          child: Builder(builder: builder),
        ),
      ),
    );
    return themes?.wrap(page) ?? page;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reducedMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    // Made once per route and disposed with it: a CurvedAnimation made on
    // every build would leave a listener on the route's animation each time.
    final curved = _curved ??= CurvedAnimation(
      parent: animation,
      curve: Curves.linear,
      reverseCurve: OsdMotion.sheetCloseCurve.flipped,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => FractionalTranslation(
        translation: Offset(0, 1 - curved.value),
        child: child,
      ),
      child: child,
    );
  }
}

/// The sheet spring from [start] to open, landing exactly on 1 (a spring
/// stops within a tolerance, which would leave the sheet a fraction of a pixel
/// low).
class _OpenSpring extends Simulation {
  _OpenSpring(double start)
    : _spring = SpringSimulation(OsdMotion.sheetSpring, start, 1, 0);

  final SpringSimulation _spring;

  @override
  double x(double time) => _spring.isDone(time) ? 1 : _spring.x(time);

  @override
  double dx(double time) => _spring.isDone(time) ? 0 : _spring.dx(time);

  @override
  bool isDone(double time) => _spring.isDone(time);
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.route, required this.child});

  final OsdSheetRoute<dynamic> route;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: route.busy,
    builder: (context, busy, child) => PopScope(
      canPop: !busy,
      child: GestureDetector(
        onVerticalDragUpdate: (details) =>
            route._dragUpdate(details.primaryDelta ?? 0, context.size!.height),
        onVerticalDragEnd: (details) =>
            route._dragEnd(details.primaryVelocity ?? 0, context.size!.height),
        child: child,
      ),
    ),
    child: child,
  );
}

/// A modal bottom sheet: the handle, an [OsdSheetTitle] and the [child]. Its
/// bottom padding follows the keyboard.
///
/// Children sit on `OsdSurface` sheet, so neutral buttons turn C2. The sheet
/// scopes and names its route with [title]. Open it with [showOsdSheet].
class OsdSheet extends StatelessWidget {
  const OsdSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.titleIcon,
    this.titleIconColor,
    this.titleTrailing,
    this.looseSubtitle = false,
    this.height = OsdSheetHeight.content,
  });

  static const Key surfaceKey = Key('osdSheet.surface');

  final String title;

  final Widget child;

  final String? subtitle;

  /// A leading accent icon for the title.
  final IconData? titleIcon;

  final Color? titleIconColor;

  /// An action at the end of the title's line (a help button).
  final Widget? titleTrailing;

  /// Whether the subtitle uses the loose line height.
  final bool looseSubtitle;

  final OsdSheetHeight height;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = math.max(
      0.0,
      media.size.height -
          media.viewPadding.top -
          (height == OsdSheetHeight.tall ? 62 : 8),
    );
    final heading = OsdSheetTitle(
      title: title,
      subtitle: subtitle,
      icon: titleIcon,
      iconColor: titleIconColor,
      trailing: titleTrailing,
      looseSubtitle: looseSubtitle,
    );
    final Widget body = switch (height) {
      OsdSheetHeight.content => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: OsdSpace.sheetGap,
          children: <Widget>[const OsdSheetHandle(), heading, child],
        ),
      ),
      OsdSheetHeight.tall => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: OsdSpace.sheetGap,
        children: <Widget>[
          const OsdSheetHandle(),
          heading,
          Flexible(child: child),
        ],
      ),
    };
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Material(
        key: surfaceKey,
        color: context.colors.sh,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(OsdRadius.r28),
          ),
        ),
        child: OsdSurface(
          tone: OsdSurfaceTone.sheet,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: AnimatedPadding(
              padding: OsdSpace.sheetPadding(context),
              duration: OsdMotion.d(context, OsdMotion.fast),
              curve: Curves.easeOut,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
