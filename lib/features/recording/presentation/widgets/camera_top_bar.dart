import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:one_second_diary/features/recording/presentation/camera_layout.dart';
import 'package:one_second_diary/features/recording/presentation/camera_motion.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_chrome_fade.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/coach_bubble.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/orientation_lock_chip.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/upright_rotation.dart';
import 'package:one_second_diary/shared/widgets/buttons/camera_icon_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/fade_on_enable.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// Which explanation the bubble gives.
enum _Explains {
  /// The lock keeps this orientation.
  locked,

  /// The clip turns with the phone again.
  unlocked,
}

/// The bar over the preview: close at the start, the orientation lock at the
/// end, and under the lock, when it was just tapped, the bubble that says what
/// it does.
///
/// - The lock freezes the way the phone is held now, for this camera. It is
///   gone while both cameras record (their clip is always upright).
/// - The bubble goes after a few seconds, on a tap, and when a take starts;
///   with a screen reader it stays until dismissed.
/// - Close and the lock fade out during a take, while the clip editor replaces
///   the camera, and while the settings sheet is open.
/// - The glyphs stay upright as the phone turns.
class CameraTopBar extends StatefulWidget {
  const CameraTopBar({super.key, required this.settingsOpen});

  static const Key closeKey = Key('cameraTopBar.close');
  static const Key lockKey = Key('cameraTopBar.lock');
  static const Key bubbleKey = Key('cameraTopBar.bubble');

  /// Whether the recording settings sheet is open.
  final bool settingsOpen;

  @override
  State<CameraTopBar> createState() => _CameraTopBarState();
}

class _CameraTopBarState extends State<CameraTopBar> {
  static const double _rise = 8;

  _Explains? _explains;
  Timer? _timeout;

  void _toggleLock(bool wasLocked) {
    context.read<RecordingBloc>().add(const RecordingLockToggled());
    final _Explains explains = wasLocked
        ? _Explains.unlocked
        : _Explains.locked;
    setState(() => _explains = explains);
    _timeout?.cancel();
    if (MediaQuery.accessibleNavigationOf(context)) return;
    _timeout = Timer(switch (explains) {
      _Explains.locked => CameraMotion.lockedBubbleHold,
      _Explains.unlocked => CameraMotion.unlockedBubbleHold,
    }, _dismiss);
  }

  void _dismiss() {
    _timeout?.cancel();
    if (_explains != null && mounted) setState(() => _explains = null);
  }

  @override
  void didUpdateWidget(CameraTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The settings sheet has its own words for the lock.
    if (widget.settingsOpen && !oldWidget.settingsOpen) {
      _timeout?.cancel();
      _explains = null;
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (
      RecordingStatus status,
      DeviceOrientation orientation,
      DeviceOrientation? lockedOrientation,
      bool dual,
    ) = context.select(
      (RecordingBloc bloc) => (
        bloc.state.status,
        bloc.state.orientation,
        bloc.state.lockedOrientation,
        bloc.state.dual,
      ),
    );
    // A kept take keeps the recording layout until the clip editor has
    // replaced the camera.
    final bool taking =
        status == RecordingStatus.countingDown ||
        status == RecordingStatus.recording ||
        status == RecordingStatus.done;
    final bool visible = !taking && !widget.settingsOpen;
    final bool locked = lockedOrientation != null;
    final bool landscape = _isLandscape(lockedOrientation ?? orientation);
    final String label = !locked
        ? Strings.cameraOrientationAutoRotate
        : landscape
        ? Strings.cameraOrientationLockedLandscape
        : Strings.cameraOrientationLockedPortrait;
    final _Explains? explains = visible ? _explains : null;
    final double chipMaxWidth =
        MediaQuery.sizeOf(context).width -
        2 * CameraLayout.topBarSide -
        CameraLayout.topControl -
        CameraLayout.closeToChip;
    return BlocListener<RecordingBloc, RecordingState>(
      // A take starting dismisses the bubble.
      listenWhen: (RecordingState previous, RecordingState current) =>
          current.status != previous.status &&
          (current.status == RecordingStatus.countingDown ||
              current.status == RecordingStatus.recording),
      listener: (BuildContext context, RecordingState state) => _dismiss(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CameraChromeFade(
            visible: visible,
            duration: OsdMotion.selection,
            rise: _rise,
            child: UprightRotation(
              orientation: orientation,
              child: CameraIconButton.glass(
                key: CameraTopBar.closeKey,
                icon: OsdIcons.close,
                tooltip: Strings.cameraCloseSemantics,
                onPressed: () => unawaited(Navigator.maybePop(context)),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: CameraChromeFade(
                // Both cameras record upright only: nothing to lock.
                visible: visible && !dual,
                duration: OsdMotion.selection,
                rise: _rise,
                child: TapRegion(
                  onTapOutside: (_) => _dismiss(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: chipMaxWidth),
                        child: FadeOnEnable(
                          enabled: status == RecordingStatus.ready,
                          child: OrientationLockChip(
                            key: CameraTopBar.lockKey,
                            locked: locked,
                            label: label,
                            icon: !locked
                                ? OsdIcons.screenRotation
                                : landscape
                                ? OsdIcons.screenLockLandscape
                                : OsdIcons.screenLockPortrait,
                            semanticsLabel: Strings.cameraOrientationSemantics(
                              state: label,
                            ),
                            orientation: orientation,
                            onPressed: status == RecordingStatus.ready
                                ? () => _toggleLock(locked)
                                : null,
                          ),
                        ),
                      ),
                      // The chip's 48 hit area reaches 2 below it.
                      const SizedBox(
                        height:
                            CameraLayout.chipToBubble -
                            (OsdSizes.minTap - CameraLayout.topControl) / 2,
                      ),
                      _Bubble(
                        explains: explains,
                        landscape: landscape,
                        onDismiss: _dismiss,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isLandscape(DeviceOrientation orientation) =>
      orientation == DeviceOrientation.landscapeLeft ||
      orientation == DeviceOrientation.landscapeRight;
}

/// The bubble under the lock: it comes in growing from the arrow's tip and
/// fades out; under reduced motion it only fades. A tap on it dismisses it.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.explains,
    required this.landscape,
    required this.onDismiss,
  });

  static const double _scaleFrom = .92;
  static const double _drop = 4;

  final _Explains? explains;
  final bool landscape;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    final String word = landscape
        ? Strings.cameraOrientationWordLandscape
        : Strings.cameraOrientationWordPortrait;
    final Widget? bubble = switch (explains) {
      null => null,
      _Explains.locked => CoachBubble(
        key: const ValueKey<_Explains>(_Explains.locked),
        text: Strings.cameraOrientationLockedExplainer(orientation: word),
        emphasis: word,
      ),
      _Explains.unlocked => CoachBubble(
        key: const ValueKey<_Explains>(_Explains.unlocked),
        text: Strings.cameraOrientationAutoExplainer,
      ),
    };
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, OsdMotion.selection),
      reverseDuration: OsdMotion.fast,
      switchInCurve: OsdMotion.curve(context, CameraMotion.bubbleInCurve),
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: AlignmentDirectional.topEnd,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Widget faded = FadeTransition(opacity: animation, child: child);
        if (reduced) return faded;
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) => Transform.translate(
            offset: Offset(0, -_drop * (1 - animation.value)),
            child: Transform.scale(
              scale: _scaleFrom + (1 - _scaleFrom) * animation.value,
              // From the arrow's tip, near the end of the top edge.
              alignment: AlignmentDirectional.topEnd.resolve(
                Directionality.of(context),
              ),
              child: child,
            ),
          ),
          child: faded,
        );
      },
      child: bubble == null
          ? const SizedBox.shrink()
          : Semantics(
              key: bubble.key,
              liveRegion: true,
              child: GestureDetector(
                key: CameraTopBar.bubbleKey,
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: bubble,
              ),
            ),
    );
  }
}
