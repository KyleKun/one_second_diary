import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/clip_editor/presentation/clip_canvas.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clip_editor/presentation/sheets/framing_sheet.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/card_crossfade.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_info_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The framing card: whether the clip sits on its profile's canvas by
/// default ("Automatic") or as framed in the framing sheet ("Custom").
/// The whole card opens the sheet, once the source's shape is known.
class FramingCard extends StatelessWidget {
  const FramingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileKey key = context.select(
      (EditClipCubit editor) => editor.state.draft.profile,
    );
    final ClipFormat format = context.select(
      (ProfilesCubit profiles) => ClipCanvas.formatOf(profiles.state, key),
    );
    final bool framed = context.select(
      (EditClipCubit editor) =>
          editor.state.draft.frameFor(format.orientation) != null,
    );
    final bool ready = context.select(
      (EditClipCubit editor) =>
          editor.state.status == EditClipStatus.ready &&
          editor.state.sourceAspectRatio != null,
    );
    final OsdColors colors = context.colors;
    return CardCrossfade(
      id: framed,
      child: OsdInfoCard(
        leading: OsdIcon(OsdIcons.crop, size: 22, color: colors.co),
        label: Strings.framingSheetTitle,
        value: framed ? Strings.saveVideoCropCustom : Strings.saveVideoCropAuto,
        valueMuted: !ready,
        trailing: OsdIcon(OsdIcons.chevronRight, size: 22, color: colors.fa),
        onTap: ready
            ? () => unawaited(FramingSheet.show(context, format: format))
            : null,
      ),
    );
  }
}
