import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_error_scope.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// What [OsdSnackbar.show] asks the host to show.
@immutable
class OsdSnackbarRequest {
  const OsdSnackbarRequest({
    required this.kind,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionErrorTitle,
    this.duration,
    this.onDismissed,
  });

  final OsdSnackKind kind;

  final String title;

  final String? subtitle;

  final String? actionLabel;

  final Future<void> Function()? onAction;

  /// The error title shown when [onAction] throws.
  final String? actionErrorTitle;

  /// Overrides the default duration.
  final Duration? duration;

  /// Called once when the snackbar leaves without its action having
  /// succeeded: it timed out, was swiped away, hidden (a tab switch),
  /// replaced by another, removed when the app went to the background, or
  /// its host went away. A failed action turns it into an error, whose
  /// leaving calls this too.
  final VoidCallback? onDismissed;
}

/// Shows floating snackbars over [child]: above the page and its nav, below
/// sheets and dialogs (which are routes on top).
///
/// Wrap the shell body with nav, and every pushed page that shows snackbars.
/// One snackbar at a time: a new one replaces the current one. It leaves
/// after a timeout (longer with an action or under `accessibleNavigation`);
/// the timer pauses while it is pressed or its action runs; a swipe down or
/// sideways dismisses it; it is removed when the app goes to the background.
class OsdSnackbarHost extends StatefulWidget {
  const OsdSnackbarHost({super.key, required this.child});

  /// The positioned slot holding the current snackbar.
  static const Key slotKey = Key('osdSnackbarHost.slot');

  /// The page (and nav) the snackbars float over.
  final Widget child;

  static OsdSnackbarHostState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_HostScope>()?.state;

  /// Throws a [StateError] when there is no host above [context].
  static OsdSnackbarHostState of(BuildContext context) {
    final host = maybeOf(context);
    if (host == null) {
      throw StateError(
        'No OsdSnackbarHost above this context. Wrap the shell body and the '
        'pushed page in OsdSnackbarHost.',
      );
    }
    return host;
  }

  @override
  State<OsdSnackbarHost> createState() => OsdSnackbarHostState();
}

class _Entry {
  _Entry(this.id, OsdSnackbarRequest request)
    : kind = request.kind,
      title = request.title,
      subtitle = request.subtitle,
      actionLabel = request.actionLabel,
      onAction = request.onAction,
      actionErrorTitle = request.actionErrorTitle,
      duration = request.duration,
      onDismissed = request.onDismissed;

  final int id;
  OsdSnackKind kind;
  String title;
  String? subtitle;
  String? actionLabel;
  Future<void> Function()? onAction;
  final String? actionErrorTitle;
  Duration? duration;
  final VoidCallback? onDismissed;
  bool busy = false;
  bool exiting = false;

  /// Whether its end is settled: [onDismissed] ran, or the action
  /// succeeded.
  bool settled = false;

  /// Runs [onDismissed] unless the end is already settled. While the action
  /// runs, its outcome settles it instead (see `_runAction`).
  void dismissed() {
    if (settled || busy) return;
    settled = true;
    onDismissed?.call();
  }
}

/// The state of an [OsdSnackbarHost]: shows and hides snackbars and tracks
/// the `SnackbarAnchor`s below it.
class OsdSnackbarHostState extends State<OsdSnackbarHost>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _enter = AnimationController(vsync: this);
  late final AnimationController _exit = AnimationController(vsync: this);

  // The countdown must keep real time even when the platform disables
  // animations (which would otherwise shorten it 20×).
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onCountdown);

  final Set<SnackbarAnchorState> _anchors = <SnackbarAnchorState>{};
  _Entry? _entry;
  int _serial = 0;
  double? _bottom;
  Offset _drag = Offset.zero;
  bool _held = false;
  bool _measureScheduled = false;

  bool get isShowing => _entry != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _entry?.dismissed();
    WidgetsBinding.instance.removeObserver(this);
    _enter.dispose();
    _exit.dispose();
    _countdown.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _removeNow();
    }
  }

  /// Registers an anchor (called by `SnackbarAnchor`).
  void attachAnchor(SnackbarAnchorState anchor) {
    _anchors.add(anchor);
    if (_entry != null) _scheduleMeasure();
  }

  void detachAnchor(SnackbarAnchorState anchor) {
    _anchors.remove(anchor);
    if (_entry != null) _scheduleMeasure();
  }

  /// Shows [request], replacing the current snackbar.
  void show(OsdSnackbarRequest request) {
    _entry?.dismissed();
    final entry = _Entry(++_serial, request);
    _drag = Offset.zero;
    _held = false;
    _exit.value = 0;
    _enter
      ..duration = OsdMotion.d(context, OsdMotion.snackIn)
      ..forward(from: 0);
    setState(() {
      _entry = entry;
      _bottom = _measure();
    });
    _restartCountdown();
    _announce(entry);
  }

  /// Hides the current snackbar with its exit motion.
  void hide() => _dismiss();

  void _removeNow() {
    final entry = _entry;
    if (entry == null) return;
    entry.dismissed();
    _countdown.stop();
    _enter.stop();
    _exit.stop();
    setState(() => _entry = null);
  }

  Duration _durationOf(_Entry entry) {
    final explicit = entry.duration;
    if (explicit != null) return explicit;
    if (MediaQuery.accessibleNavigationOf(context)) {
      return const Duration(seconds: 10);
    }
    return entry.actionLabel == null
        ? const Duration(milliseconds: 4000)
        : const Duration(milliseconds: 5000);
  }

  void _restartCountdown() {
    final entry = _entry;
    if (entry == null) return;
    _countdown.duration = _durationOf(entry);
    _countdown.value = 0;
    if (!_held && !entry.busy) unawaited(_countdown.forward());
  }

  void _pause() {
    _held = true;
    _countdown.stop();
  }

  void _resume() {
    _held = false;
    final entry = _entry;
    if (entry == null || entry.busy || entry.exiting) return;
    unawaited(_countdown.forward());
  }

  void _onCountdown(AnimationStatus status) {
    if (status == AnimationStatus.completed) _dismiss();
  }

  void _dismiss() {
    final entry = _entry;
    if (entry == null || entry.exiting) return;
    entry
      ..exiting = true
      ..dismissed();
    _countdown.stop();
    _exit
      ..duration = OsdMotion.d(context, OsdMotion.snackOut)
      ..forward(from: 0).whenCompleteOrCancel(() {
        if (mounted && identical(_entry, entry) && _exit.isCompleted) {
          setState(() => _entry = null);
        }
      });
  }

  Future<void> _runAction(_Entry entry) async {
    final action = entry.onAction;
    if (action == null || entry.busy || entry.exiting) return;
    final OsdErrorReporter report = OsdErrorScope.of(context);
    setState(() => entry.busy = true);
    _countdown.stop();
    try {
      await action();
      entry.settled = true;
      if (!mounted || !identical(_entry, entry)) return;
      _dismiss();
    } on Object catch (error, stackTrace) {
      report(
        'The snackbar action "${entry.actionLabel}" failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted || !identical(_entry, entry)) {
        // Replaced or gone while the action ran: it left without it.
        entry
          ..busy = false
          ..dismissed();
        return;
      }
      setState(() {
        entry
          ..busy = false
          ..kind = OsdSnackKind.error
          ..title = entry.actionErrorTitle ?? entry.title
          ..subtitle = null
          ..actionLabel = null
          ..onAction = null
          ..duration = null;
      });
      _restartCountdown();
      _announce(entry);
    }
  }

  void _announce(_Entry entry) {
    final subtitle = entry.subtitle;
    final message = subtitle == null
        ? entry.title
        : '${entry.title}. $subtitle';
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  double _fallbackBottom() {
    final media = MediaQuery.of(context);
    return OsdSpace.snackbarNoAnchor +
        math.max(media.viewPadding.bottom, media.viewInsets.bottom);
  }

  /// The snackbar's distance from the host's bottom: above the highest live
  /// anchor plus its gap, or the fallback gap above the inset.
  double _measure() {
    final host = context.findRenderObject();
    if (host is! RenderBox || !host.hasSize) return _fallbackBottom();
    double? best;
    for (final anchor in _anchors) {
      if (!anchor.isActive) continue;
      final box = anchor.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: host).dy;
      final bottom = host.size.height - top + anchor.gap;
      if (best == null || bottom > best) best = bottom;
    }
    return best ?? _fallbackBottom();
  }

  /// Measures the anchors after the next frame, and after every frame while
  /// a snackbar shows: an anchor that moves, grows or changes its gap under a
  /// snackbar already up (Today's controls swapping at midnight) takes the
  /// snackbar with it. Nothing runs between frames, and a frame only comes
  /// when something on screen changed or the snackbar animates.
  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted || _entry == null) return;
      final bottom = _measure();
      if (_bottom == null || (bottom - _bottom!).abs() > .5) {
        setState(() => _bottom = bottom);
      }
      _scheduleMeasure();
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (_drag.dx.abs() > 64 ||
        _drag.dy > 24 ||
        velocity.dx.abs() > 700 ||
        velocity.dy > 700) {
      _dismiss();
    } else {
      setState(() => _drag = Offset.zero);
    }
    _resume();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild (and re-measure the anchors) when insets or size change.
    MediaQuery.sizeOf(context);
    MediaQuery.viewInsetsOf(context);
    MediaQuery.viewPaddingOf(context);
    final entry = _entry;
    if (entry != null) _scheduleMeasure();
    return _HostScope(
      state: this,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          widget.child,
          if (entry != null)
            Positioned(
              key: OsdSnackbarHost.slotKey,
              left: OsdSpace.pageGutter,
              right: OsdSpace.pageGutter,
              bottom: _bottom ?? _fallbackBottom(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: OsdSizes.snackbarMaxWidth,
                  ),
                  child: AnimatedBuilder(
                    animation: Listenable.merge(<Listenable>[_enter, _exit]),
                    builder: (context, child) {
                      final reduced = OsdMotion.reduced(context);
                      final enter = reduced
                          ? _enter.value
                          : OsdMotion.snackInCurve.transform(_enter.value);
                      final exit = reduced
                          ? _exit.value
                          : OsdMotion.snackOutCurve.transform(_exit.value);
                      final rise = reduced
                          ? 0.0
                          : OsdMotion.snackInOffset * (1 - enter) +
                                OsdMotion.snackOutOffset * exit;
                      return Opacity(
                        opacity: (enter * (1 - exit)).clamp(0, 1),
                        child: Transform.translate(
                          offset: Offset(_drag.dx, rise + _drag.dy),
                          child: child,
                        ),
                      );
                    },
                    child: Listener(
                      onPointerDown: (_) => _pause(),
                      onPointerUp: (_) => _resume(),
                      onPointerCancel: (_) => _resume(),
                      child: GestureDetector(
                        onPanUpdate: (details) => setState(
                          () => _drag = Offset(
                            _drag.dx + details.delta.dx,
                            math.max(0, _drag.dy + details.delta.dy),
                          ),
                        ),
                        onPanEnd: _onDragEnd,
                        child: OsdSnackbar(
                          kind: entry.kind,
                          title: entry.title,
                          subtitle: entry.subtitle,
                          actionLabel: entry.actionLabel,
                          busy: entry.busy,
                          onAction: entry.onAction == null
                              ? null
                              : () => unawaited(_runAction(entry)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HostScope extends InheritedWidget {
  const _HostScope({required this.state, required super.child});

  final OsdSnackbarHostState state;

  @override
  bool updateShouldNotify(_HostScope oldWidget) => false;
}
