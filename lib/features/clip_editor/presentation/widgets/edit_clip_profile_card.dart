import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/card_crossfade.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_switch_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_pill_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_info_card.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';

/// The profile this clip goes to, with "Change".
///
/// "Change" opens the profile switch sheet for this clip only: the app's
/// profile stays. A new pick crossfades the card, and the preview takes
/// its canvas. A replace has no "Change": it writes over a clip of its
/// profile.
class EditClipProfileCard extends StatelessWidget {
  const EditClipProfileCard({super.key});

  static const Key changeKey = Key('editClipProfileCard.change');

  @override
  Widget build(BuildContext context) {
    final ProfileKey key = context.select(
      (EditClipCubit editor) => editor.state.draft.profile,
    );
    final bool changeable = context.select(
      (EditClipCubit editor) => editor.state.canChangeProfile,
    );
    final Profile profile = context.select(
      (ProfilesCubit profiles) => profiles.state.profiles.firstWhere(
        (Profile candidate) => candidate.key == key,
        orElse: () => profiles.state.active,
      ),
    );
    return CardCrossfade(
      id: profile,
      child: OsdInfoCard(
        leading: ProfileAvatar(profile: profile, size: 36),
        label: Strings.currentProfile,
        value: profile.displayName,
        valueMaxLines: OsdTextScale.nameLines(context),
        trailing: changeable
            ? OsdPillButton(
                key: changeKey,
                label: Strings.change,
                onPressed: () =>
                    unawaited(_change(context, current: profile.key)),
              )
            : null,
      ),
    );
  }

  Future<void> _change(
    BuildContext context, {
    required ProfileKey current,
  }) async {
    final EditClipCubit editor = context.read<EditClipCubit>();
    final ProfileKey? picked = await ProfileSwitchSheet.show(
      context,
      selected: current,
      title: Strings.saveVideoSavingInto,
    );
    if (picked == null || editor.isClosed) return;
    editor.profileChanged(picked);
  }
}
