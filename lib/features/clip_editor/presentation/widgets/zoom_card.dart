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

/// The General tab's "Slow zoom" card, for a photo source only: on (the
/// default), the photo drifts closer over the clip (`PhotoZoom`); off, it
/// holds still.
class ZoomCard extends StatelessWidget {
  const ZoomCard({super.key});

  static const Key cardKey = Key('zoomCard.card');

  void _toggle(BuildContext context) {
    final EditClipCubit editor = context.read<EditClipCubit>();
    editor.zoomChanged(zoom: !editor.state.draft.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final bool photo = context.select(
      (EditClipCubit editor) => editor.state.args.source is PhotoSource,
    );
    if (!photo) return const SizedBox.shrink();
    final bool zoom = context.select(
      (EditClipCubit editor) => editor.state.draft.zoom,
    );
    final OsdColors colors = context.colors;
    // One node for a screen reader: the card's "label, value" with the
    // switch's on/off (both toggle it).
    return MergeSemantics(
      child: OsdInfoCard(
        key: cardKey,
        leading: OsdIcon(OsdIcons.openInFull, size: 22, color: colors.purple),
        label: Strings.saveVideoZoom,
        value: Strings.saveVideoZoomHint,
        valueMuted: !zoom,
        trailing: OsdSwitch(value: zoom, onChanged: (_) => _toggle(context)),
        onTap: () => _toggle(context),
      ),
    );
  }
}
