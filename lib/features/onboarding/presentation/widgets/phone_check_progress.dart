import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/onboarding/domain/phone_check_progress.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The phone check's progress: a thin bar over the tests, "3 of 9" and
/// the test in flight ("Testing 4K 60 fps · HEVC · Stereo"), a live region.
/// The bar follows a change smoothly; under reduced motion it jumps, and
/// there is no shimmer either way.
class PhoneCheckProgressBar extends StatelessWidget {
  const PhoneCheckProgressBar({super.key, required this.progress});

  static const Key trackKey = Key('phoneCheckProgress.track');
  static const Key fillKey = Key('phoneCheckProgress.fill');
  static const Key labelKey = Key('phoneCheckProgress.label');

  static const double _height = 6;

  /// Null before the first test reports.
  final PhoneCheckProgress? progress;

  /// The line under the bar for [progress].
  static String labelOf(PhoneCheckProgress progress) => switch (progress.test) {
    PhoneCheckTest.encode => Strings.phoneCheckTestEncode(
      format: progress.format == null
          ? ''
          : ProfileLabels.format(progress.format!),
    ),
    PhoneCheckTest.decode => Strings.phoneCheckTestDecode,
    PhoneCheckTest.camera => Strings.phoneCheckTestCamera,
    PhoneCheckTest.storage => Strings.phoneCheckTestStorage,
  };

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final PhoneCheckProgress? progress = this.progress;
    final BorderRadius radius = BorderRadius.circular(_height / 2);
    final Duration duration = OsdMotion.d(context, OsdMotion.emphasized);
    final Curve curve = OsdMotion.curve(context, OsdMotion.standardCurve);
    final LocaleFormats formats = LocaleFormats.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: OsdSpace.s10,
      children: <Widget>[
        ExcludeSemantics(
          child: SizedBox(
            height: _height,
            child: DecoratedBox(
              key: trackKey,
              decoration: BoxDecoration(
                color: colors.off,
                borderRadius: radius,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progress?.fraction ?? 0),
                duration: duration,
                curve: curve,
                builder: (BuildContext context, double value, _) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    heightFactor: 1,
                    child: DecoratedBox(
                      key: fillKey,
                      decoration: BoxDecoration(
                        color: colors.co,
                        borderRadius: radius,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            progress == null
                ? Strings.phoneCheckBody
                : '${Strings.phoneCheckProgress(done: formats.numbers.format(progress.done), total: formats.numbers.format(progress.total))} · ${labelOf(progress)}',
            key: labelKey,
            style: typography.label13.copyWith(color: colors.mu),
          ),
        ),
      ],
    );
  }
}
