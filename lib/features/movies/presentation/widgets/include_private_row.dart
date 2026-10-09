import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/presentation/privacy/private_help_button.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The confirmation's "Include private clips" switch, there only when the
/// movie's range holds private clips (clips picked by hand are taken as picked,
/// so they have no switch).
class IncludePrivateRow extends StatelessWidget {
  const IncludePrivateRow({super.key});

  /// The switch row.
  static const Key rowKey = Key('includePrivateRow.row');

  static const Key helpKey = Key('includePrivateRow.help');

  Future<void> _toggle(
    BuildContext context, {
    required bool included,
    required int count,
  }) async {
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    if (included) return flow.setIncludePrivate(include: false);
    final bool confirmed = await OsdConfirmDialog.show(
      context,
      title: Strings.movieIncludePrivateConfirmTitle,
      body: Strings.movieIncludePrivateConfirmBody(
        count,
        format: MovieLabels.numberFormat(context),
      ),
      cancelLabel: CommonLabels.of(context).cancel,
      confirmLabel: Strings.movieIncludePrivateConfirm,
      badgeIcon: OsdIcons.lock,
    );
    if (confirmed) flow.setIncludePrivate(include: true);
  }

  @override
  Widget build(BuildContext context) {
    final ({int count, bool included}) flow = context
        .select<CreateMovieCubit, ({int count, bool included})>(
          (CreateMovieCubit flow) => (
            count: flow.state.draft?.privateInRange ?? 0,
            included: flow.state.includePrivate,
          ),
        );
    return AnimatedSize(
      duration: OsdMotion.d(context, OsdMotion.standard),
      curve: OsdMotion.curve(context, OsdMotion.standardCurve),
      alignment: Alignment.topCenter,
      child: flow.count == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                spacing: 4,
                children: <Widget>[
                  Expanded(
                    child: OsdCard(
                      child: OsdListRow(
                        key: rowKey,
                        icon: OsdIcons.lock,
                        title: Strings.movieIncludePrivate,
                        subtitle: flow.included
                            ? Strings.moviePrivateIncluded(
                                flow.count,
                                format: MovieLabels.numberFormat(context),
                              )
                            : Strings.moviePrivateLeftOut(
                                flow.count,
                                format: MovieLabels.numberFormat(context),
                              ),
                        trailing: OsdRowTrailing.custom(
                          OsdSwitch(value: flow.included, interactive: false),
                        ),
                        toggled: flow.included,
                        haptic: OsdHaptic.selection,
                        onTap: () => unawaited(
                          _toggle(
                            context,
                            included: flow.included,
                            count: flow.count,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const PrivateHelpButton(key: helpKey),
                ],
              ),
            ),
    );
  }
}
