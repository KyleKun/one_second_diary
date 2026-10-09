import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/presentation/clip_canvas.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/sheets/date_stamp_sheet.dart';
import 'package:one_second_diary/features/clip_editor/presentation/stamp_texts.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/card_crossfade.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/media/stamp_color_dot.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_info_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The date-stamp card: the stamp colour and the date as the export burns
/// it (another format crossfades the card). The whole card opens the date
/// stamp sheet.
class DateStampCard extends StatelessWidget {
  const DateStampCard({super.key});

  /// How long the dot takes to reach a new colour.
  static const Duration colorTween = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final LocalDay day = context.select(
      (EditClipCubit editor) => editor.state.args.day,
    );
    final StampStyle stamp = context.select(
      (EditClipCubit editor) => editor.state.draft.stamp,
    );
    return CardCrossfade(
      id: stamp.format,
      child: OsdInfoCard(
        leading: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: Color(0xFF000000 | stamp.rgb)),
          duration: OsdMotion.d(context, colorTween),
          curve: OsdMotion.curve(context, OsdMotion.fastCurve),
          builder: (BuildContext context, Color? color, _) =>
              StampColorDot(color: color!),
        ),
        label: Strings.dateColorAndFormat,
        value: StampTexts.of(context, day: day, format: stamp.format),
        trailing: OsdIcon(
          OsdIcons.chevronRight,
          size: 22,
          color: context.colors.fa,
        ),
        onTap: () => unawaited(
          DateStampSheet.show(
            context,
            format: ClipCanvas.formatOf(
              context.read<ProfilesCubit>().state,
              context.read<EditClipCubit>().state.draft.profile,
            ),
          ),
        ),
      ),
    );
  }
}
