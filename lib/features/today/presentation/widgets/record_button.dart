import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/router/hero_tags.dart';
import 'package:one_second_diary/features/today/presentation/today_motion.dart';
import 'package:one_second_diary/features/today/presentation/widgets/record_halo_painter.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hero.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Today's record button: a coral disc with the filled `videocam`, between
/// Add video and Add photo.
///
/// - Its halo sits outside its layout box ([RecordHaloPainter]).
/// - Pressed, it scales down under a dark veil while the rings grow; a tap
///   plays the medium haptic.
/// - While the day waits for its clip ([breathing]) it glows: two discs grow out of it and fade over
///   `TodayMotion.recordGlow`, then it rests for `recordGlowRest`. The loop stops in a hidden tab (`TickerMode`)
///   and under reduced motion, where two still rings show instead, and it only repaints the halo.
/// - The disc flies to the camera's shutter (`HeroTags.recordShutter`),
///   only from the tab on screen.
/// - [compact] (short screens): a smaller disc and rings.
/// - Disabled while Today loads (null [onPressed]): dimmed, no breathing.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.onPressed,
    required this.semanticsLabel,
    this.breathing = false,
    this.compact = false,
  });

  static const Key discKey = Key('recordButton.disc');

  static const Key haloKey = Key('recordButton.halo');

  /// How far the halo reaches past the disc at its widest: a glow at its
  /// end, or the outer ring held down. The halo takes no layout space, so
  /// whatever sits around the button keeps this clear (the snackbar on
  /// Today, the nav under it).
  static double haloReach({required bool compact}) => math.max(
    RecordHaloPainter.glowReach(_size(compact: compact) / 2),
    _outerSpread(compact: compact) + RecordHaloPainter.pressOuterGrowth,
  );

  /// The disc's diameter.
  static double _size({required bool compact}) => compact ? 80 : 92;

  static double _innerSpread({required bool compact}) => compact ? 8 : 10;

  static double _outerSpread({required bool compact}) => compact ? 18 : 22;

  /// Opens the camera; null disables the button.
  final VoidCallback? onPressed;

  final String semanticsLabel;

  /// Whether the halo glows (the day has no clip yet).
  final bool breathing;

  /// The short-screen size.
  final bool compact;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: TodayMotion.recordGlow + TodayMotion.recordGlowRest,
  );

  /// Bumped each time the tab comes back on screen: the hero is remade,
  /// so a flight that ended while a page covered Today can't leave the
  /// disc hidden behind its placeholder.
  int _heroGeneration = 0;
  bool _onScreen = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool onScreen = TickerMode.valuesOf(context).enabled;
    if (onScreen && !_onScreen) _heroGeneration++;
    _onScreen = onScreen;
    _syncBreathing();
  }

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBreathing();
  }

  void _syncBreathing() {
    final bool breathe =
        widget.breathing &&
        widget.onPressed != null &&
        OsdMotion.loopsEnabled(context);
    if (breathe && !_breath.isAnimating) {
      _breath.repeat();
    } else if (!breathe && _breath.value != 0) {
      _breath.value = 0;
    } else if (!breathe) {
      _breath.stop();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Widget button = OsdPressable(
      opacity: OsdPressable.opacityFor(enabled: enabled),
      onTap: widget.onPressed,
      pressScale: OsdPressScale.icon.scale,
      overlay: OsdPressOverlay.darken,
      shape: BoxShape.circle,
      haptic: OsdHaptic.medium,
      semanticsLabel: widget.semanticsLabel,
      excludeChildSemantics: true,
      child: _RecordVisual(
        glow: _breath,
        compact: widget.compact,
        heroKey: ValueKey<int>(_heroGeneration),
      ),
    );
    return button;
  }
}

/// The disc and its halo, which grows while the button is held down.
class _RecordVisual extends StatelessWidget {
  const _RecordVisual({
    required this.glow,
    required this.compact,
    required this.heroKey,
  });

  final AnimationController glow;
  final bool compact;
  final Key heroKey;

  static const double _iconSize = 44;
  static const double _compactIconSize = 38;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final bool pressed = OsdPressable.isPressed(context);
    final double size = RecordButton._size(compact: compact);
    final Widget disc = OsdHero(
      key: heroKey,
      tag: HeroTags.recordShutter,
      radius: size / 2,
      child: DecoratedBox(
        key: RecordButton.discKey,
        decoration: BoxDecoration(color: colors.co, shape: BoxShape.circle),
        child: Center(
          child: OsdIcon(
            OsdIcons.videocam,
            size: compact ? _compactIconSize : _iconSize,
            fill: 1,
            color: colors.onCo,
          ),
        ),
      ),
    );
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: pressed ? 1 : 0),
          duration: OsdMotion.d(
            context,
            pressed ? OsdMotion.pressIn : OsdMotion.pressOut,
          ),
          curve: OsdMotion.curve(
            context,
            pressed ? OsdMotion.pressInCurve : OsdMotion.pressOutCurve,
          ),
          builder: (BuildContext context, double press, Widget? child) =>
              CustomPaint(
                key: RecordButton.haloKey,
                painter: RecordHaloPainter(
                  color: colors.co,
                  innerSpread: RecordButton._innerSpread(compact: compact),
                  outerSpread: RecordButton._outerSpread(compact: compact),
                  press: press,
                  pulse: glow,
                  glowShare:
                      TodayMotion.recordGlow.inMicroseconds /
                      (TodayMotion.recordGlow + TodayMotion.recordGlowRest)
                          .inMicroseconds,
                ),
                child: child,
              ),
          child: disc,
        ),
      ),
    );
  }
}
