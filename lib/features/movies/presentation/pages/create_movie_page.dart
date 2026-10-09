import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/choose_dates_sheet.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/choose_month_sheet.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/clips_found_count.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_options_card.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_preset_card.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_profile_chip.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_tags_card.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/scroll_under_footer.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Create movie, "Which days?": the flow's profile chip, the six ranges with
/// the clips found live, "Choose a month", "Choose dates" and "Pick videos
/// myself", the tag filter when the profile has tagged clips, then Continue to
/// the confirmation.
class CreateMoviePage extends StatelessWidget {
  const CreateMoviePage({super.key});

  static const Key continueKey = Key('createMoviePage.continue');

  static const double _maxWidth = 560;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final double bottom = math.max(
      24,
      MediaQuery.viewPaddingOf(context).bottom + 8,
    );
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: OsdAppBar(
        title: Strings.createMovie,
        trailing: const MovieProfileChip(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: ScrollUnderFooter(
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      8,
                      20,
                      14,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        Strings.createMovieWhichDays,
                        maxLines: 2,
                        textScaler: OsdTextScale.scalerFor(
                          context,
                          OsdTextScaleRole.display,
                        ),
                        style: context.typography.displayHeading.copyWith(
                          color: colors.tx,
                        ),
                      ),
                    ),
                  ),
                  const MoviePresetCard(),
                  const SizedBox(height: 10),
                  MovieOptionsCard(
                    onChooseMonth: () => unawaited(_chooseMonth(context)),
                    onChooseDates: () => unawaited(_chooseDates(context)),
                    onPickVideos: () =>
                        unawaited(AppRoute.pickClips.push<void>(context)),
                  ),
                  const MovieTagsCard(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            footer: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: <Widget>[
                  const ClipsFoundCount(),
                  _ContinueButton(onPressed: () => _continue(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _continue(BuildContext context) {
    context.read<CreateMovieCubit>().confirmPreset();
    unawaited(AppRoute.confirmMovie.push<void>(context));
  }

  /// Once a month is chosen, the confirmation opens after the sheet has
  /// gone, so the two motions never overlap.
  Future<void> _chooseMonth(BuildContext context) async {
    final bool chosen = await ChooseMonthSheet.show(context);
    if (context.mounted) await _confirmAfter(context, chosen: chosen);
  }

  /// The same for the days chosen.
  Future<void> _chooseDates(BuildContext context) async {
    final bool chosen = await ChooseDatesSheet.show(context);
    if (context.mounted) await _confirmAfter(context, chosen: chosen);
  }

  Future<void> _confirmAfter(
    BuildContext context, {
    required bool chosen,
  }) async {
    if (!chosen) return;
    await Future<void>.delayed(
      OsdMotion.reduced(context) ? Duration.zero : OsdMotion.afterSheetClose,
    );
    if (context.mounted) unawaited(AppRoute.confirmMovie.push<void>(context));
  }
}

/// Continue, on while the range has enough clips.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = context.select<CreateMovieCubit, bool>(
      (CreateMovieCubit flow) => flow.state.canContinue,
    );
    return PrimaryButton(
      key: CreateMoviePage.continueKey,
      label: CommonLabels.of(context).continueAction,
      size: OsdButtonSize.large,
      haptic: OsdHaptic.light,
      onPressed: enabled ? onPressed : null,
    );
  }
}
