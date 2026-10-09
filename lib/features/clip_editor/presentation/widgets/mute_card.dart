import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_info_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The General tab's "Save without sound" card, for a video source only: off, the clip keeps the recording's sound;
/// on, a silent track takes its place. The choice is the draft's, written only when the clip is.
class MuteCard extends StatelessWidget {
  const MuteCard({super.key});

  static const Key cardKey = Key('muteCard.card');

  void _toggle(BuildContext context) {
    final EditClipCubit editor = context.read<EditClipCubit>();
    editor.muteChanged(mute: !editor.state.draft.mute);
  }

  @override
  Widget build(BuildContext context) {
    final bool video = context.select(
      (EditClipCubit editor) => editor.state.args.source is VideoSource,
    );
    if (!video) return const SizedBox.shrink();
    final bool mute = context.select(
      (EditClipCubit editor) => editor.state.draft.mute,
    );
    final OsdColors colors = context.colors;
    // One node for a screen reader: the card's "label, value" with the
    // switch's on/off (both toggle it).
    return MergeSemantics(
      child: OsdInfoCard(
        key: cardKey,
        leading: OsdIcon(OsdIcons.volumeOff, size: 22, color: colors.purple),
        label: Strings.saveVideoMute,
        value: Strings.saveVideoMuteHint,
        valueMuted: !mute,
        trailing: OsdSwitch(value: mute, onChanged: (_) => _toggle(context)),
        onTap: () => _toggle(context),
      ),
    );
  }
}
