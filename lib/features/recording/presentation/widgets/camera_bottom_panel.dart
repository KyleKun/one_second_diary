import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/platform/camera_lens.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length_format.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:one_second_diary/features/recording/presentation/camera_layout.dart';
import 'package:one_second_diary/features/recording/presentation/camera_motion.dart';
import 'package:one_second_diary/features/recording/presentation/camera_numbers.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_chrome_fade.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_entrance.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/clip_length_chip.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/shutter_button.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/upright_rotation.dart';
import 'package:one_second_diary/shared/widgets/buttons/camera_icon_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/fade_on_enable.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The black panel under the preview: the clip-length chip, then tune, the
/// shutter and the camera switch. Snackbars float above it.
///
/// The controls work while the camera is ready; the shutter also works during
/// a take. During a take the chip, tune and switch fade out and the shutter
/// morphs in place; they stay out while the clip editor replaces the camera or
/// the settings sheet is open. The glyphs stay upright as the phone turns.
class CameraBottomPanel extends StatelessWidget {
  const CameraBottomPanel({
    super.key,
    required this.clock,
    required this.settingsOpen,
    required this.onOpenSettings,
    required this.onStop,
  });

  static const Key clipLengthKey = Key('cameraBottomPanel.clipLength');
  static const Key tuneKey = Key('cameraBottomPanel.tune');
  static const Key shutterKey = Key('cameraBottomPanel.shutter');
  static const Key switchKey = Key('cameraBottomPanel.switch');

  /// The switch's glyph is 26 where tune's is the solid button's 24: an
  /// optical correction.
  static const double _switchGlyph = 26;
  static const double _shrink = .8;

  /// How much of the take is recorded (the shutter's ring).
  final ValueListenable<double> clock;

  /// Whether the recording settings sheet is open.
  final bool settingsOpen;

  /// The chip and tune open the recording settings.
  final VoidCallback onOpenSettings;

  /// The stop square, during a recording.
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final (
      RecordingStatus status,
      int clipSeconds,
      DeviceOrientation orientation,
      bool canSwitchLens,
      CameraFacing? facing,
    ) = context.select(
      (RecordingBloc bloc) => (
        bloc.state.status,
        bloc.state.clipSeconds,
        bloc.state.orientation,
        bloc.state.canSwitchLens,
        bloc.state.lens?.facing,
      ),
    );
    final RecordingBloc bloc = context.read<RecordingBloc>();
    final bool ready = status == RecordingStatus.ready;
    // A kept take keeps the recording layout until the clip editor has
    // replaced the camera.
    final bool taking =
        status == RecordingStatus.countingDown ||
        status == RecordingStatus.recording ||
        status == RecordingStatus.done;
    final bool controls = !taking && !settingsOpen;
    // Records (or cancels the countdown), or stops the recording.
    final VoidCallback? shutter = switch (status) {
      RecordingStatus.ready || RecordingStatus.countingDown => () => bloc.add(
        const RecordingShutterPressed(),
      ),
      RecordingStatus.recording => onStop,
      _ => null,
    };
    // Seconds ("5 seconds"); minutes and seconds past 59 s ("1:00").
    final String length = ClipLengthFormat.showsMinutes(clipSeconds)
        ? ClipLengthFormat.minutes(clipSeconds)
        : Strings.cameraClipLengthSeconds(
            clipSeconds,
            format: CameraNumbers.of(context),
          );
    return SnackbarAnchor(
      gap: OsdSpace.snackbarAboveCta,
      child: ColoredBox(
        color: OsdCamera.black,
        child: Stack(
          children: <Widget>[
            // The chip's 48 hit area reaches 8 past it both ways.
            Positioned(
              top:
                  CameraLayout.panelTopPadding -
                  (OsdSizes.minTap - CameraLayout.chipHeight) / 2,
              left: 0,
              right: 0,
              child: Center(
                child: _Secondary(
                  visible: controls,
                  child: FadeOnEnable(
                    enabled: ready,
                    child: ClipLengthChip(
                      key: clipLengthKey,
                      label: length,
                      semanticsLabel: Strings.cameraClipLengthSemantics(
                        length: length,
                      ),
                      orientation: orientation,
                      onPressed: ready ? onOpenSettings : null,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: CameraLayout.shutterRowTop,
              left: 0,
              right: 0,
              height: CameraLayout.shutterSize,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: CameraLayout.shutterRowMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CameraLayout.shutterRowPadding,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _Secondary(
                          visible: controls,
                          shrink: _shrink,
                          child: UprightRotation(
                            orientation: orientation,
                            child: FadeOnEnable(
                              enabled: ready,
                              child: CameraIconButton.solid(
                                key: tuneKey,
                                icon: OsdIcons.tune,
                                tooltip: Strings.recordingSettings,
                                onPressed: ready ? onOpenSettings : null,
                              ),
                            ),
                          ),
                        ),
                        ShutterButton(
                          key: shutterKey,
                          mode: switch (status) {
                            RecordingStatus.countingDown => ShutterMode.armed,
                            RecordingStatus.recording ||
                            RecordingStatus.done => ShutterMode.recording,
                            _ => ShutterMode.idle,
                          },
                          progress: clock,
                          semanticsLabel: switch (status) {
                            RecordingStatus.countingDown => CommonLabels.of(
                              context,
                            ).cancel,
                            RecordingStatus.recording ||
                            RecordingStatus.done => Strings.cameraStopSemantics,
                            _ => Strings.record,
                          },
                          onPressed: shutter,
                          dim: switch (status) {
                            // Today's record button has just landed on the
                            // disc.
                            RecordingStatus.opening => ShutterDim.ring,
                            RecordingStatus.done => ShutterDim.none,
                            _ => ShutterDim.all,
                          },
                        ),
                        _Secondary(
                          visible: controls && canSwitchLens,
                          shrink: _shrink,
                          child: UprightRotation(
                            orientation: orientation,
                            child: _Flip(
                              facing: facing,
                              // One node: "Switch camera", "Back camera".
                              child: FadeOnEnable(
                                enabled: ready && canSwitchLens,
                                child: MergeSemantics(
                                  child: Semantics(
                                    value: facing == CameraFacing.front
                                        ? Strings.cameraFrontCamera
                                        : Strings.cameraBackCamera,
                                    child: CameraIconButton.solid(
                                      key: switchKey,
                                      icon: OsdIcons.cameraswitch,
                                      glyphSize: _switchGlyph,
                                      tooltip: Strings.cameraSwitchSemantics,
                                      onPressed: ready && canSwitchLens
                                          ? () => bloc.add(
                                              const RecordingLensSwitched(),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A control around the shutter: it comes in as the page lands, and steps
/// back during a take or while the settings are open (the chip fades; tune
/// and switch also shrink).
class _Secondary extends StatelessWidget {
  const _Secondary({required this.visible, required this.child, this.shrink});

  final bool visible;
  final Widget child;

  /// The scale tune and switch shrink to; the chip only fades.
  final double? shrink;

  @override
  Widget build(BuildContext context) {
    final double? shrink = this.shrink;
    return CameraChromeFade(
      visible: visible,
      duration: shrink == null ? OsdMotion.fast : OsdMotion.selection,
      shrink: shrink ?? 1,
      child: CameraEntrance(child: child),
    );
  }
}

/// The camera switch's glyph turns half a turn each time the other lens
/// opens; at once under reduced motion.
class _Flip extends StatefulWidget {
  const _Flip({required this.facing, required this.child});

  final CameraFacing? facing;
  final Widget child;

  @override
  State<_Flip> createState() => _FlipState();
}

class _FlipState extends State<_Flip> {
  double _turns = 0;

  @override
  void didUpdateWidget(_Flip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facing != null &&
        widget.facing != null &&
        oldWidget.facing != widget.facing) {
      _turns += .5;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: _turns,
    // Under reduced motion it turns at once; the value "Front camera" says
    // the lens changed.
    duration: OsdMotion.reduced(context) ? Duration.zero : OsdMotion.emphasized,
    curve: CameraMotion.morphCurve,
    child: widget.child,
  );
}
