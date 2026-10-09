import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:one_second_diary/core/router/hero_tags.dart';
import 'package:one_second_diary/features/recording/presentation/camera_motion.dart';
import 'package:one_second_diary/features/recording/presentation/widgets/camera_entrance.dart';
import 'package:one_second_diary/shared/widgets/foundation/fade_on_enable.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hero.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/progress/recording_progress_ring.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// What the shutter shows.
enum ShutterMode {
  /// The white ring and the coral disc; a tap records.
  idle,

  /// Counting down: the stop square in an empty ring; a tap cancels.
  armed,

  /// The stop square in the ring that fills with the clock; a tap stops.
  recording,
}

/// What shows that the shutter is off (it has no `onPressed`).
enum ShutterDim {
  /// All of it: the camera can't record (no access, an error, the app
  /// away).
  all,

  /// The ring only: the lens is opening, and the disc stays lit where
  /// Today's record button has just landed.
  ring,

  /// Nothing: the take is handed to the clip editor, and the shutter stays
  /// as it was until the camera has gone.
  none,
}

/// The camera's shutter:
/// - idle: a white ring and a coral disc, which Today's record button flies
///   into (`HeroTags.recordShutter`);
/// - armed / recording: the disc morphs into a stop square while the ring
///   crossfades into the [RecordingProgressRing], which follows [progress]
///   (a clock, linear, also under reduced motion);
/// - off (no [onPressed]): it ignores taps and dims as [dim] says.
///
/// Its tree never changes with its state, so the morph carries on whatever
/// happens to it.
class ShutterButton extends StatelessWidget {
  const ShutterButton({
    super.key,
    required this.mode,
    required this.progress,
    required this.semanticsLabel,
    this.onPressed,
    this.dim = ShutterDim.all,
  });

  /// The white ring (idle).
  static const Key ringKey = Key('shutterButton.ring');

  /// The coral disc, or the stop square.
  static const Key discKey = Key('shutterButton.disc');

  static const double _size = 88;
  static const double _ringWidth = 4;
  static const double _ringEntranceScale = .9;
  static const double _disc = 68;
  static const double _square = 32;
  static const double _squareRadius = 8;

  final ShutterMode mode;

  /// How much of the take is recorded, 0 to 1.
  final ValueListenable<double> progress;

  /// What a tap does: "Record", "Cancel" (the countdown) or "Stop
  /// recording".
  final String semanticsLabel;

  /// Called on a tap; null turns the shutter off.
  final VoidCallback? onPressed;

  /// What shows that the shutter is off; nothing dims while it is on.
  final ShutterDim dim;

  @override
  Widget build(BuildContext context) {
    final bool taking = mode != ShutterMode.idle;
    final bool on = onPressed != null;
    final Duration crossfade = OsdMotion.d(context, OsdMotion.selection);
    final Duration morph = OsdMotion.d(context, OsdMotion.standard);
    final Curve morphCurve = OsdMotion.curve(context, CameraMotion.morphCurve);
    final double side = taking ? _square : _disc;
    final Widget visual = SizedBox.square(
      dimension: _size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _Lit(
            lit: on || dim == ShutterDim.none,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AnimatedOpacity(
                  opacity: taking ? 0 : 1,
                  duration: crossfade,
                  child: const CameraEntrance(
                    scaleFrom: _ringEntranceScale,
                    child: DecoratedBox(
                      key: ringKey,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: OsdCamera.white, width: _ringWidth),
                        ),
                      ),
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: taking ? 1 : 0,
                  duration: crossfade,
                  child: RecordingProgressRing(progress: progress),
                ),
              ],
            ),
          ),
          // Outside the hero: what flies is the disc as it is when lit.
          _Lit(
            lit: on || dim != ShutterDim.all,
            child: OsdHero(
              tag: HeroTags.recordShutter,
              radius: _disc / 2,
              child: SizedBox.square(
                dimension: _disc,
                child: Center(
                  child: _PressSink(
                    child: AnimatedContainer(
                      key: discKey,
                      duration: morph,
                      curve: morphCurve,
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        color: context.colors.co,
                        borderRadius: BorderRadius.circular(
                          taking ? _squareRadius : _disc / 2,
                        ),
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
    return OsdPressable(
      onTap: onPressed,
      pressScale: null,
      overlay: OsdPressOverlay.none,
      shape: BoxShape.circle,
      semanticsLabel: semanticsLabel,
      child: visual,
    );
  }
}

/// A part of the shutter: dimmed at once while it is not [lit], fading
/// back when it is ([FadeOnEnable]). Its wrappers stay in the tree either
/// way, so what they hold keeps its state.
class _Lit extends StatelessWidget {
  const _Lit({required this.lit, required this.child});

  final bool lit;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeOnEnable(
    enabled: lit,
    child: Opacity(
      opacity: lit ? 1 : OsdPressable.disabledOpacity,
      child: child,
    ),
  );
}

/// The disc sinking while the shutter is held, and springing back when let
/// go (`OsdMotion.shutterSpring`). Under reduced motion it sinks less and
/// comes back without the spring.
class _PressSink extends StatefulWidget {
  const _PressSink({required this.child});

  final Widget child;

  @override
  State<_PressSink> createState() => _PressSinkState();
}

class _PressSinkState extends State<_PressSink>
    with SingleTickerProviderStateMixin {
  static const double _sunk = .9;

  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool pressed = OsdPressable.isPressed(context);
    if (pressed == _pressed) return;
    _pressed = pressed;
    final bool reduced = OsdMotion.reduced(context);
    if (pressed) {
      _scale
          .animateTo(
            reduced
                ? OsdMotion.pressScale(context, OsdPressScale.button)
                : _sunk,
            duration: OsdMotion.pressIn,
            curve: OsdMotion.pressInCurve,
          )
          .ignore();
    } else if (reduced) {
      _scale.animateTo(1, duration: OsdMotion.pressOut).ignore();
    } else {
      // A spring stops within a tolerance; the disc lands exactly on 1.
      unawaited(
        _scale
            .animateWith(
              SpringSimulation(
                OsdMotion.shutterSpring,
                _scale.value,
                1,
                _scale.velocity,
              ),
            )
            .then((_) => _scale.value = 1),
      );
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
