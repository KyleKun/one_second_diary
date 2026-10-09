import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The recording timer: a dot that pulses (`OsdMotion.recPulse`; still under
/// reduced motion) before [label] in tabular figures. The time always reads
/// left to right. The page announces the recording, so the pill is not read
/// out every second.
class RecordingTimerPill extends StatefulWidget {
  const RecordingTimerPill({super.key, required this.label});

  static const Key surfaceKey = Key('recordingTimerPill.surface');

  static const Key dotKey = Key('recordingTimerPill.dot');

  static const double _minHeight = 34;
  static const double _dot = 8;

  /// "00:01 / 00:02".
  final String label;

  @override
  State<RecordingTimerPill> createState() => _RecordingTimerPillState();
}

class _RecordingTimerPillState extends State<RecordingTimerPill>
    with SingleTickerProviderStateMixin {
  static const double _dimmed = .35;

  // Half a pulse each way: 1 → .35 → 1 takes `recPulse`.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: OsdMotion.recPulse ~/ 2,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: _dimmed,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (OsdMotion.loopsEnabled(context)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true).ignore();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.typography.titleSmall.copyWith(
      color: OsdCamera.white,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        key: RecordingTimerPill.surfaceKey,
        decoration: BoxDecoration(
          color: context.colors.co,
          borderRadius: BorderRadius.circular(OsdRadius.full),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: RecordingTimerPill._minHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: OsdSpace.s16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: OsdSpace.iconLabelGap,
              children: <Widget>[
                FadeTransition(
                  opacity: _opacity,
                  child: const SizedBox.square(
                    key: RecordingTimerPill.dotKey,
                    dimension: RecordingTimerPill._dot,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: OsdCamera.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  textScaler: OsdTextScale.scalerFor(
                    context,
                    OsdTextScaleRole.mediaChrome,
                  ),
                  style: style,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
