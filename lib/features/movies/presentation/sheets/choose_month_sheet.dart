import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/month_grid.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/year_stepper.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';

/// Choose a month: the year stepper, the twelve months of that year with their
/// clips, and Continue.
class ChooseMonthSheet extends StatelessWidget {
  const ChooseMonthSheet({super.key});

  static const Key bodyKey = Key('chooseMonthSheet.body');
  static const Key continueKey = Key('chooseMonthSheet.continue');

  /// Opens the sheet on the flow's month.
  static Future<bool> show(BuildContext context) async {
    final CreateMovieCubit flow = context.read<CreateMovieCubit>()
      ..openMonthPicker();
    final bool? chosen = await showOsdSheet<bool>(
      context,
      title: Strings.chooseMonth,
      child: BlocProvider<CreateMovieCubit>.value(
        value: flow,
        child: const ChooseMonthSheet(),
      ),
    );
    return chosen ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final MonthChoice? choice = context.select<CreateMovieCubit, MonthChoice?>(
      (CreateMovieCubit flow) => flow.state.monthChoice,
    );
    final ({bool previous, bool next}) steps = context
        .select<CreateMovieCubit, ({bool previous, bool next})>(
          (CreateMovieCubit flow) => (
            previous: flow.state.canShowPreviousYear,
            next: flow.state.canShowNextYear,
          ),
        );
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    final int year = choice?.year ?? flow.state.today.year;
    return Column(
      key: bodyKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: <Widget>[
        YearStepper(
          year: MovieLabels.year(context, year),
          previousTooltip: Strings.previousYear,
          nextTooltip: Strings.nextYear,
          onPrevious: steps.previous
              ? () {
                  unawaited(OsdHaptic.selection.play());
                  flow.showYear(year - 1);
                }
              : null,
          onNext: steps.next
              ? () {
                  unawaited(OsdHaptic.selection.play());
                  flow.showYear(year + 1);
                }
              : null,
        ),
        const MonthGrid(),
        PrimaryButton(
          key: continueKey,
          label: CommonLabels.of(context).continueAction,
          size: OsdButtonSize.standard,
          haptic: OsdHaptic.light,
          onPressed: choice?.month == null
              ? null
              : () {
                  flow.confirmMonth();
                  Navigator.of(context).pop(true);
                },
        ),
      ],
    );
  }
}
