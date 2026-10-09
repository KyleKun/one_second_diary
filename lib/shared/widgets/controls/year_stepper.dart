import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/year_stepper_button.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The year row of the "Choose a month" sheet: chevron buttons at the ends
/// and the [year] between them. A new year slides in with a fade and is
/// announced (live region).
class YearStepper extends StatelessWidget {
  const YearStepper({
    super.key,
    required this.year,
    required this.onPrevious,
    required this.onNext,
    required this.previousTooltip,
    required this.nextTooltip,
  });

  static const Key surfaceKey = Key('yearStepper.surface');

  static const Duration _switch = Duration(milliseconds: 200);
  static const double _slide = 8;

  /// The year, formatted for the locale.
  final String year;

  /// Null at the earliest year with clips.
  final VoidCallback? onPrevious;

  /// Null at the current year.
  final VoidCallback? onNext;

  final String previousTooltip;

  final String nextTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduced = OsdMotion.reduced(context);
    return DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: colors.c2,
        borderRadius: BorderRadius.circular(OsdRadius.r16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: <Widget>[
            YearStepperButton(
              icon: OsdIcons.chevronLeft,
              tooltip: previousTooltip,
              onPressed: onPrevious,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: OsdMotion.d(context, _switch),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: reduced
                        ? child
                        : AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                0,
                                _slide *
                                    (1 -
                                        Curves.easeOutCubic.transform(
                                          animation.value,
                                        )),
                              ),
                              child: child,
                            ),
                            child: child,
                          ),
                  ),
                  child: Text(
                    year,
                    key: ValueKey<String>(year),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    textScaler: OsdTextScale.scalerFor(
                      context,
                      OsdTextScaleRole.display,
                    ),
                    style: context.typography.displayValue.copyWith(
                      color: colors.tx,
                    ),
                  ),
                ),
              ),
            ),
            YearStepperButton(
              icon: OsdIcons.chevronRight,
              tooltip: nextTooltip,
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}
