import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/recording/domain/recording_timing.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:one_second_diary/features/recording/presentation/camera_layout.dart';
import 'package:one_second_diary/features/recording/presentation/camera_numbers.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_bottom_panel.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_chrome_fade.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_entrance.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_top_bar.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_viewfinder.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/microphone_off_pill.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/recording_settings_sheet.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/recording_timer_pill.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_listener.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// The in-app camera, always dark, over the route's [RecordingBloc]: the
/// preview edge to edge above the black panel, the top bar over it, and the
/// timer pill.
///
/// - A kept recording opens the clip editor in the camera's place
///   (`EditClipArgs.pushReplacement`), so the editor's `SavedClip` completes
///   the push that opened the camera.
/// - The recording clock starts when the camera does (`RecordingTiming.captureOf`):
///   the shutter's ring follows it every frame, the timer pill once a second,
///   and nothing else rebuilds while recording.
/// - The app's lifecycle goes to the bloc, which releases the camera while the
///   app is away.
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  static const Key timerKey = Key('cameraPage.timer');

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with SingleTickerProviderStateMixin {
  late final AppLifecycleListener _lifecycle;

  /// The take's clock, 0 to 1 over the whole capture. It is a clock: it
  /// keeps real time under reduced motion (the platform setting would run
  /// an ordinary controller at 5 %).
  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_ticked);

  /// The whole seconds recorded, at most the clip length (the capture's
  /// extra second is the editor's to trim).
  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);

  bool _settingsOpen = false;

  /// Whether the take was stopped with the stop square (its haptic was
  /// played then).
  bool _stoppedByTap = false;

  /// The status the page last reacted to.
  late RecordingStatus _status = context.read<RecordingBloc>().state.status;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (AppLifecycleState lifecycle) => context
          .read<RecordingBloc>()
          .add(RecordingLifecycleChanged(lifecycle)),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _clock.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  void _ticked() {
    final Duration capture = _clock.duration ?? Duration.zero;
    final int seconds = (capture * _clock.value).inSeconds;
    _elapsed.value = math.min(
      seconds,
      context.read<RecordingBloc>().state.clipSeconds,
    );
  }

  void _statusChanged(RecordingState state) {
    final RecordingStatus was = _status;
    _status = state.status;
    switch (state.status) {
      case RecordingStatus.recording:
        _stoppedByTap = false;
        _elapsed.value = 0;
        _clock
          ..duration = RecordingTiming.captureOf(state.clipSeconds)
          ..forward(from: 0).ignore();
        unawaited(OsdHaptic.medium.play());
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            Strings.cameraRecordingAnnouncement,
            Directionality.of(context),
          ),
        );
      case RecordingStatus.done:
        _clock.stop();
        if (was == RecordingStatus.recording && !_stoppedByTap) {
          unawaited(OsdHaptic.medium.play());
        }
        unawaited(state.handOff!.pushReplacement<SavedClip>(context));
      case RecordingStatus.cancelled:
        Navigator.of(context).pop();
      case RecordingStatus.opening ||
          RecordingStatus.needsPermission ||
          RecordingStatus.ready ||
          RecordingStatus.countingDown ||
          RecordingStatus.failed ||
          RecordingStatus.paused ||
          RecordingStatus.usingSystemCamera:
        _clock
          ..stop()
          ..value = 0;
    }
  }

  void _stop() {
    _stoppedByTap = true;
    unawaited(OsdHaptic.light.play());
    context.read<RecordingBloc>().add(const RecordingStopPressed());
  }

  Future<void> _openSettings() async {
    setState(() => _settingsOpen = true);
    await RecordingSettingsSheet.show(context);
    if (mounted) setState(() => _settingsOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final double panelHeight = CameraLayout.panelHeightOf(context);
    final double safeTop = MediaQuery.viewPaddingOf(context).top;
    // Close and the lock have 48 hit areas around 44 visuals.
    const double hitOverhang = (OsdSizes.minTap - CameraLayout.topControl) / 2;
    return MultiBlocListener(
      listeners: <BlocListener<RecordingBloc, RecordingState>>[
        BlocListener<RecordingBloc, RecordingState>(
          listenWhen: (RecordingState previous, RecordingState current) =>
              previous.status != current.status,
          listener: (BuildContext context, RecordingState state) =>
              _statusChanged(state),
        ),
        BlocListener<RecordingBloc, RecordingState>(
          listenWhen: (RecordingState previous, RecordingState current) =>
              current.countdown != null &&
              previous.countdown != current.countdown,
          listener: (BuildContext context, RecordingState state) =>
              unawaited(OsdHaptic.selection.play()),
        ),
      ],
      child: _TakeGuard(
        child: OsdSnackbarHost(
          child: _Notices(
            child: Scaffold(
              backgroundColor: OsdCamera.black,
              resizeToAvoidBottomInset: false,
              body: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: panelHeight,
                    child: const CameraViewfinder(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: panelHeight,
                    child: CameraBottomPanel(
                      clock: _clock,
                      settingsOpen: _settingsOpen,
                      onOpenSettings: () => unawaited(_openSettings()),
                      onStop: _stop,
                    ),
                  ),
                  Positioned(
                    top: safeTop + CameraLayout.timerPillBelowInset,
                    left: 0,
                    right: 0,
                    child: _TimerSlot(elapsed: _elapsed),
                  ),
                  Positioned(
                    top:
                        safeTop +
                        CameraLayout.topBarBelowInset +
                        CameraLayout.topControl +
                        CameraLayout.topBarToHint,
                    left: CameraLayout.topBarSide,
                    right: CameraLayout.topBarSide,
                    child: const _HintSlot(),
                  ),
                  PositionedDirectional(
                    top: safeTop + CameraLayout.topBarBelowInset - hitOverhang,
                    start: CameraLayout.topBarSide - hitOverhang,
                    end: CameraLayout.topBarSide,
                    child: CameraEntrance(
                      child: CameraTopBar(settingsOpen: _settingsOpen),
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

/// The timer pill, centred under the status bar while recording: the whole
/// seconds recorded out of the clip length, rebuilt once a second.
class _TimerSlot extends StatelessWidget {
  const _TimerSlot({required this.elapsed});

  static const double _rise = 8;

  final ValueListenable<int> elapsed;

  @override
  Widget build(BuildContext context) {
    final (bool recording, int clipSeconds) = context.select(
      (RecordingBloc bloc) => (
        bloc.state.status == RecordingStatus.recording,
        bloc.state.clipSeconds,
      ),
    );
    final String total = CameraNumbers.clock(clipSeconds);
    return Center(
      child: CameraChromeFade(
        key: CameraPage.timerKey,
        visible: recording,
        duration: OsdMotion.standard,
        rise: _rise,
        child: ValueListenableBuilder<int>(
          valueListenable: elapsed,
          builder: (BuildContext context, int seconds, _) => RecordingTimerPill(
            label: Strings.recordingTimerProgress(
              elapsed: CameraNumbers.clock(seconds),
              total: total,
            ),
          ),
        ),
      ),
    );
  }
}

/// The hint pills, centred under the top bar while the camera is open:
/// "Microphone off" when it records without sound, "Hold upright" when
/// both cameras record and the phone is held sideways (their clip is
/// upright whatever the phone does), and "Focus and exposure locked" after
/// a long press on the preview.
class _HintSlot extends StatelessWidget {
  const _HintSlot();

  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final (bool microphoneOff, bool sideways, bool focusLocked) = context
        .select((RecordingBloc bloc) {
          final RecordingState state = bloc.state;
          final bool open = switch (state.status) {
            RecordingStatus.ready ||
            RecordingStatus.countingDown ||
            RecordingStatus.recording => true,
            _ => false,
          };
          return (
            open && state.microphoneOff,
            open &&
                state.dual &&
                switch (state.orientation) {
                  DeviceOrientation.landscapeLeft ||
                  DeviceOrientation.landscapeRight => true,
                  DeviceOrientation.portraitUp ||
                  DeviceOrientation.portraitDown => false,
                },
            open && state.focusLocked,
          );
        });
    if (!microphoneOff && !sideways && !focusLocked) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: _gap,
      children: <Widget>[
        if (microphoneOff) const MicrophoneOffPill(),
        if (sideways) const DualUprightPill(),
        if (focusLocked) const FocusLockedPill(),
      ],
    );
  }
}

/// Says what happened to the last take, once, in a snackbar: too short,
/// the camera failed, the app went away, or both cameras gave way to one. A failure offers "Report
/// error", and says so when the phone has no mail app.
class _Notices extends StatelessWidget {
  const _Notices({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordingBloc, RecordingState>(
      listenWhen: (RecordingState previous, RecordingState current) =>
          previous.notice != current.notice && current.notice != null,
      listener: (BuildContext context, RecordingState state) {
        final (
          OsdSnackKind kind,
          String title,
          String body,
        ) = switch (state.notice!) {
          RecordingNotice.tooShort => (
            OsdSnackKind.info,
            Strings.cameraTooShortTitle,
            Strings.cameraTooShortBody,
          ),
          RecordingNotice.recordFailed => (
            OsdSnackKind.error,
            Strings.recordingErrorTitle,
            Strings.cameraRecordFailedBody,
          ),
          RecordingNotice.interrupted => (
            OsdSnackKind.info,
            Strings.cameraInterruptedTitle,
            Strings.cameraInterruptedBody,
          ),
          RecordingNotice.dualFailed => (
            OsdSnackKind.info,
            Strings.cameraDualFailedTitle,
            Strings.cameraDualFailedBody,
          ),
        };
        final bool failed = state.notice == RecordingNotice.recordFailed;
        OsdSnackbar.show(
          context,
          kind: kind,
          title: title,
          subtitle: body,
          actionLabel: failed ? Strings.reportError : null,
          onAction: failed
              ? () => context.read<ReportErrorCubit>().report(
                  body: Strings.errorMailBody,
                )
              : null,
        );
      },
      // A report that finds no mail app says so, with Copy address.
      child: ReportErrorListener(child: child),
    );
  }
}

/// Back during a countdown or a recording drops the take and keeps the
/// camera; back again closes it.
class _TakeGuard extends StatelessWidget {
  const _TakeGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool taking = context.select(
      (RecordingBloc bloc) => switch (bloc.state.status) {
        RecordingStatus.countingDown || RecordingStatus.recording => true,
        _ => false,
      },
    );
    return PopScope<Object?>(
      canPop: !taking,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          context.read<RecordingBloc>().add(const RecordingCancelled());
        }
      },
      child: child,
    );
  }
}
