import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:one_second_diary/features/recording/presentation/camera_motion.dart';
import 'package:one_second_diary/features/recording/presentation/camera_numbers.dart';
import 'package:one_second_diary/features/recording/presentation/camera_preview_geometry.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_preview_view.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_state_overlay.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/countdown_overlay.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/focus_ring.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';

/// The preview's rect, edge to edge above the panel: the [CameraPreviewView],
/// and over it
/// - a tap focuses and exposes there and shows the [FocusRing]; a long press
///   holds focus and exposure (AE/AF lock) until the next tap; a pinch zooms;
///   a vertical one-finger swipe switches camera;
/// - the [CountdownOverlay];
/// - the access and error panels ([CameraStateOverlay]);
/// - a spinner while a lens takes long to open.
class CameraViewfinder extends StatefulWidget {
  const CameraViewfinder({super.key});

  /// The area that takes taps and pinches.
  static const Key gestureKey = Key('cameraViewfinder.gestures');

  @override
  State<CameraViewfinder> createState() => _CameraViewfinderState();
}

class _CameraViewfinderState extends State<CameraViewfinder> {
  /// Where the last tap focused, and how many taps there were (each shows a
  /// new ring).
  Offset? _focusedAt;
  int _taps = 0;

  /// The zoom when the pinch started.
  double _zoomAtStart = 1;

  /// How far the finger went since it came down, and whether a second
  /// finger joined (a pinch is never a swipe).
  Offset _dragged = Offset.zero;
  bool _pinching = false;

  /// How far up or down a swipe goes at least, and how much further than
  /// sideways.
  static const double _swipeDistance = 64;
  static const double _swipeSteepness = 2;

  bool _live(RecordingState state) =>
      state.session != null &&
      switch (state.status) {
        RecordingStatus.ready ||
        RecordingStatus.countingDown ||
        RecordingStatus.recording => true,
        _ => false,
      };

  void _focus(Offset at, Size box, {required bool lock}) {
    final RecordingBloc bloc = context.read<RecordingBloc>();
    final RecordingState state = bloc.state;
    // Both cameras have no focus point.
    if (!_live(state) || state.dual) return;
    final Offset point = CameraPreviewGeometry.pointAt(
      at,
      box: box,
      aspectRatio: state.session!.aspectRatio,
    );
    if (lock) unawaited(OsdHaptic.medium.play());
    bloc.add(lock ? RecordingFocusLocked(point) : RecordingFocused(point));
    setState(() {
      _focusedAt = at;
      _taps++;
    });
  }

  void _pinchStarted(ScaleStartDetails details) {
    _zoomAtStart = context.read<RecordingBloc>().state.zoom;
    _dragged = Offset.zero;
    _pinching = details.pointerCount > 1;
  }

  void _pinched(ScaleUpdateDetails details) {
    final RecordingBloc bloc = context.read<RecordingBloc>();
    if (details.pointerCount < 2) {
      _dragged += details.focalPointDelta;
      return;
    }
    _pinching = true;
    if (!_live(bloc.state)) return;
    bloc.add(RecordingZoomed(_zoomAtStart * details.scale));
  }

  /// One finger lifted after going up or down: the other camera, while the
  /// camera is ready and the phone has one (the bloc ignores it otherwise,
  /// as it does the switch button).
  void _dragEnded(ScaleEndDetails details) {
    final Offset dragged = _dragged;
    final bool pinched = _pinching;
    _dragged = Offset.zero;
    _pinching = false;
    if (pinched ||
        dragged.dy.abs() < _swipeDistance ||
        dragged.dy.abs() < dragged.dx.abs() * _swipeSteepness) {
      return;
    }
    final RecordingBloc bloc = context.read<RecordingBloc>();
    if (bloc.state.status != RecordingStatus.ready ||
        !bloc.state.canSwitchLens) {
      return;
    }
    unawaited(OsdHaptic.selection.play());
    bloc.add(const RecordingLensSwitched());
  }

  @override
  Widget build(BuildContext context) {
    final Offset? focusedAt = _focusedAt;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const CameraPreviewView(),
          // Touch only: to a screen reader the preview is no button (its
          // double tap would focus the middle, where the lens focuses
          // anyway).
          GestureDetector(
            key: CameraViewfinder.gestureKey,
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapUp: (TapUpDetails details) =>
                _focus(details.localPosition, constraints.biggest, lock: false),
            onLongPressStart: (LongPressStartDetails details) =>
                _focus(details.localPosition, constraints.biggest, lock: true),
            onScaleStart: _pinchStarted,
            onScaleUpdate: _pinched,
            onScaleEnd: _dragEnded,
          ),
          if (focusedAt != null)
            Positioned(
              left: focusedAt.dx - FocusRing.size / 2,
              top: focusedAt.dy - FocusRing.size / 2,
              child: FocusRing(key: ValueKey<int>(_taps)),
            ),
          const _Countdown(),
          const CameraStateOverlay(),
          const _OpeningSpinner(),
        ],
      ),
    );
  }
}

/// The countdown's number, in the language's digits, upright.
class _Countdown extends StatelessWidget {
  const _Countdown();

  @override
  Widget build(BuildContext context) {
    final (int? count, DeviceOrientation orientation) = context.select(
      (RecordingBloc bloc) => (bloc.state.countdown, bloc.state.orientation),
    );
    return IgnorePointer(
      child: CountdownOverlay(
        count: count,
        numeral: count == null ? '' : CameraNumbers.of(context).format(count),
        semanticsLabel: count == null
            ? ''
            : Strings.cameraCountdownSemantics(count: count),
        orientation: orientation,
      ),
    );
  }
}

/// A spinner in the middle of the preview, once a lens has taken longer
/// than [CameraMotion.spinnerDelay] to open.
class _OpeningSpinner extends StatelessWidget {
  const _OpeningSpinner();

  static const double _size = 24;
  static const double _alpha = .6;

  @override
  Widget build(BuildContext context) {
    final bool opening = context.select(
      (RecordingBloc bloc) => bloc.state.status == RecordingStatus.opening,
    );
    return IgnorePointer(
      child: OsdLoadingDelay(
        loading: opening,
        delay: CameraMotion.spinnerDelay,
        builder: (BuildContext context, bool showLoading) => showLoading
            ? Center(
                child: OsdSpinner(
                  size: _size,
                  color: context.colors.tx.withValues(alpha: _alpha),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
