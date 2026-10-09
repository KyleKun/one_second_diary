import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:one_second_diary/shared/widgets/chrome/dialog_icon_badge.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_surface.dart';
import 'package:one_second_diary/theme/osd_tints.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Shows a dialog built by [builder] (usually an [OsdDialog]) in an
/// [OsdDialogRoute]. Returns what it pops with.
Future<T?> showOsdDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  bool useRootNavigator = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push<T>(
    OsdDialogRoute<T>(
      builder: builder,
      colors: context.colors,
      reducedMotion: OsdMotion.reduced(context),
      dismissible: dismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    ),
  );
}

/// The dialog route: in and out with a fade and scale; under reduced motion
/// it only fades. Esc and the barrier cancel unless the dialog is [busy].
class OsdDialogRoute<T> extends PopupRoute<T> {
  OsdDialogRoute({
    required this.builder,
    required OsdColors colors,
    required this.reducedMotion,
    this.dismissible = true,
    this.barrierLabel,
    this.themes,
    super.settings,
  }) : _barrierColor = colors.scrimModal;

  final WidgetBuilder builder;

  final bool reducedMotion;

  /// Whether the dialog can be dismissed with the barrier or back.
  final bool dismissible;

  /// The themes between the opener and the navigator.
  final CapturedThemes? themes;

  final Color _barrierColor;

  @override
  final String? barrierLabel;

  /// Whether the dialog is busy (confirming): no dismiss of any kind.
  final ValueNotifier<bool> busy = ValueNotifier<bool>(false);

  /// The route of the dialog around [context], if any.
  static OsdDialogRoute<dynamic>? of(BuildContext context) {
    final route = ModalRoute.of(context);
    return route is OsdDialogRoute ? route : null;
  }

  /// Marks the dialog around [context] busy or idle.
  static void setBusy(BuildContext context, {required bool busy}) {
    final route = of(context);
    if (route == null || route.busy.value == busy) return;
    route.busy.value = busy;
    route.changedInternalState();
  }

  @override
  Color? get barrierColor => _barrierColor;

  @override
  bool get barrierDismissible => dismissible && !busy.value;

  @override
  Curve get barrierCurve => Curves.easeOut;

  @override
  Duration get transitionDuration =>
      reducedMotion ? OsdMotion.fast : OsdMotion.dialogIn;

  @override
  Duration get reverseTransitionDuration =>
      reducedMotion ? OsdMotion.fast : OsdMotion.dialogOut;

  @override
  void dispose() {
    busy.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget page = ValueListenableBuilder<bool>(
      valueListenable: busy,
      builder: (context, busy, child) =>
          PopScope(canPop: dismissible && !busy, child: child!),
      child: Builder(builder: builder),
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
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final closing = animation.status == AnimationStatus.reverse;
        final t = closing
            ? OsdMotion.dialogOutCurve.flipped.transform(animation.value)
            : OsdMotion.dialogInCurve.transform(animation.value);
        final from = closing
            ? OsdMotion.dialogScaleOut
            : OsdMotion.dialogScaleIn;
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(scale: from + (1 - from) * t, child: child),
        );
      },
      child: child,
    );
  }
}

/// The dialog: an optional [DialogIconBadge], a title, a body, optional
/// [content], then optional [actions]. With a badge the title and body are
/// centred.
///
/// At most the screen minus 48 tall, with the content scrolling; lifted above
/// the keyboard. Children sit on `OsdSurface` sheet. The dialog scopes and
/// names its route as an alert dialog. Show it with [showOsdDialog] (or
/// `OsdConfirmDialog.show`).
class OsdDialog extends StatelessWidget {
  const OsdDialog({
    super.key,
    required this.title,
    this.actions,
    this.body,
    this.content,
    this.badgeIcon,
    this.badgeColor,
    this.badgeTint = OsdTints.redTint12,
  });

  static const Key surfaceKey = Key('osdDialog.surface');

  final String title;

  /// The actions: an `OsdDialogActionRow`, or a single muted text button.
  /// None (and no gap for them) while the dialog waits for something that
  /// closes it, such as a migration's progress.
  final Widget? actions;

  final String? body;

  /// Extra content (a static ProfileChip, a text field, contact tiles).
  final Widget? content;

  final IconData? badgeIcon;

  /// The badge glyph colour; RED by default.
  final Color? badgeColor;

  final Color badgeTint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final media = MediaQuery.of(context);
    final badgeIcon = this.badgeIcon;
    final body = this.body;
    final content = this.content;
    final actions = this.actions;
    final centred = badgeIcon != null;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      duration: OsdMotion.d(context, OsdMotion.fast),
      curve: Curves.easeOut,
      child: Center(
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          role: SemanticsRole.alertDialog,
          label: title,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: OsdSizes.dialogWidth(media.size.width),
              minWidth: OsdSizes.dialogWidth(media.size.width),
              maxHeight: math.max(
                0,
                media.size.height - media.viewInsets.bottom - 48,
              ),
            ),
            child: Material(
              key: surfaceKey,
              color: colors.sh,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(OsdRadius.r28),
              ),
              child: OsdSurface(
                tone: OsdSurfaceTone.sheet,
                child: SingleChildScrollView(
                  padding: OsdSpace.dialogPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    spacing: OsdSpace.dialogGap,
                    children: <Widget>[
                      if (badgeIcon != null)
                        DialogIconBadge(
                          icon: badgeIcon,
                          color: badgeColor,
                          tint: badgeTint,
                        ),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: centred
                              ? TextAlign.center
                              : TextAlign.start,
                          style: typography.sheetTitle.copyWith(
                            color: colors.tx,
                          ),
                        ),
                      ),
                      if (body != null)
                        Text(
                          body,
                          textAlign: centred
                              ? TextAlign.center
                              : TextAlign.start,
                          style:
                              (centred
                                      ? typography.body15Loose
                                      : typography.body14Loose)
                                  .copyWith(color: colors.mu),
                        ),
                      ?content,
                      ?actions,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
