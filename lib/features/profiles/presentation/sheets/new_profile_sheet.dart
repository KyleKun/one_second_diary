import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/quality_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_form_listener.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_name_field.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_photo_picker.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/quality_row.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/controls/orientation_option_tile.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/shared/widgets/surfaces/field_label.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The body of the "New profile" sheet: optional photo, name, the two
/// orientations, the quality and Create.
///
/// Nothing is preselected: the canvas is permanent, so it is chosen
/// explicitly. The quality then follows the phone check's pick for that
/// canvas. Create makes the profile active and closes the sheet with it. Open
/// it with `ProfileSheets.showNew`.
class NewProfileSheet extends StatelessWidget {
  const NewProfileSheet({super.key});

  static const Key createKey = Key('newProfileSheet.create');

  /// "You can't change this later."
  static const Key hintKey = Key('newProfileSheet.hint');

  static Key orientationKey(VideoOrientation orientation) =>
      ValueKey<String>('newProfileSheet.orientation.${orientation.name}');

  /// The ratio under each tile's name: the same in every language.
  static const Map<VideoOrientation, String> _ratios =
      <VideoOrientation, String>{
        VideoOrientation.landscape: '16:9',
        VideoOrientation.portrait: '9:16',
      };

  @override
  Widget build(BuildContext context) => const OsdSnackbarHost(
    child: ProfileFormListener(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: OsdSpace.sheetGap,
        children: <Widget>[
          ProfilePhotoPicker(),
          ProfileNameField(),
          _OrientationChoice(),
          _QualityChoice(),
          _CreateButton(),
        ],
      ),
    ),
  );
}

class _OrientationChoice extends StatelessWidget {
  const _OrientationChoice();

  @override
  Widget build(BuildContext context) {
    final (VideoOrientation? chosen, bool busy) = context.select(
      (ProfileFormCubit cubit) => (cubit.state.orientation, cubit.state.isBusy),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s8,
      children: <Widget>[
        FieldLabel(label: Strings.orientation),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: <Widget>[
              for (final VideoOrientation orientation
                  in VideoOrientation.values)
                Expanded(
                  child: OrientationOptionTile.compact(
                    key: NewProfileSheet.orientationKey(orientation),
                    orientation: orientation,
                    name: ProfileLabels.orientation(orientation),
                    detail: NewProfileSheet._ratios[orientation]!,
                    selected: orientation == chosen,
                    onTap: busy
                        ? null
                        : () => context
                              .read<ProfileFormCubit>()
                              .orientationPicked(orientation),
                  ),
                ),
            ],
          ),
        ),
        // Fades out once chosen, keeping its line so Create doesn't move.
        AnimatedOpacity(
          key: NewProfileSheet.hintKey,
          opacity: chosen == null ? 1 : 0,
          duration: OsdMotion.d(context, OsdMotion.fast),
          curve: OsdMotion.curve(context, OsdMotion.fastCurve),
          child: ExcludeSemantics(
            excluding: chosen != null,
            child: Text(
              Strings.profileOrientationHint,
              maxLines: 2,
              style: context.typography.caption.copyWith(
                color: context.colors.sub,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The quality row: the pick for the chosen canvas, opening the quality
/// sheet; off until a canvas is chosen.
class _QualityChoice extends StatelessWidget {
  const _QualityChoice();

  Future<void> _open(BuildContext context) async {
    final ProfileFormCubit form = context.read<ProfileFormCubit>();
    final VideoOrientation? orientation = form.state.orientation;
    final QualityRecommendation? advice = form.state.recommendation;
    if (orientation == null || advice == null) return;
    final ClipFormat? picked = await QualitySheet.show(
      context,
      orientation: orientation,
      recommendation: advice,
      selected: form.state.format,
    );
    if (picked != null) form.formatPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final (ClipFormat? format, bool ready) = context.select(
      (ProfileFormCubit cubit) => (
        cubit.state.format,
        cubit.state.orientation != null &&
            cubit.state.recommendation != null &&
            !cubit.state.isBusy,
      ),
    );
    return QualityRow(
      format: format,
      enabled: ready,
      onTap: () => unawaited(_open(context)),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton();

  @override
  Widget build(BuildContext context) {
    final (bool canSave, bool saving) = context.select(
      (ProfileFormCubit cubit) => (cubit.state.canSave, cubit.state.isBusy),
    );
    return SnackbarAnchor(
      gap: OsdSpace.snackbarAboveCta,
      child: PrimaryButton(
        key: NewProfileSheet.createKey,
        label: Strings.create,
        haptic: OsdHaptic.medium,
        loading: saving,
        onPressed: canSave
            ? () => unawaited(context.read<ProfileFormCubit>().save())
            : null,
      ),
    );
  }
}
