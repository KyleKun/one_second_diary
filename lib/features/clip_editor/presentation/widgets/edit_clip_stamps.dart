import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/policy/stamp_filter.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/stamp_texts.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/animated_stamp_text.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/stamp_appear.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The stamps over the preview's canvas as the export burns them: a written date bottom-left, a numeric one top-right,
/// the place bottom-right, in the stamp colour with the export's outline. Size and margins are `StampFilter`'s for the [format]
/// and text size (they grow with the canvas; margin and outline don't change with the size), scaled by the preview's canvas width
/// over the format's; never mirrored. Like drawtext, nothing is truncated: a long place runs over the date and is clipped by the canvas.
///
/// The subtitle is not shown: it is a soft track a player draws its own way.
///
/// Rebuilds only when the stamp or the place changes, never on a trim.
class EditClipStamps extends StatelessWidget {
  const EditClipStamps({super.key, required this.format});

  static const Key dateKey = Key('editClipStamps.date');

  static const Key placeKey = Key('editClipStamps.place');

  /// The format the clip is made in: its canvas sizes the stamps.
  final ClipFormat format;

  @override
  Widget build(BuildContext context) {
    final LocalDay day = context.select(
      (EditClipCubit editor) => editor.state.args.day,
    );
    final StampStyle stamp = context.select(
      (EditClipCubit editor) => editor.state.draft.stamp,
    );
    final ClipLocation location = context.select(
      (EditClipCubit editor) => editor.state.draft.location,
    );
    final String date = StampTexts.of(context, day: day, format: stamp.format);
    final String? place = location.enabled && (location.text ?? '').isNotEmpty
        ? location.text
        : null;
    final Color color = Color(0xFF000000 | stamp.rgb);
    final bool written = stamp.format == StampFormat.written;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        // The preview's px per px of the canvas the export draws on.
        final double scale = width / format.width;
        final double margin = StampFilter.marginFor(format) * scale;
        final double outlineWidth = StampFilter.outlineWidthFor(format) * scale;
        final TextStyle style = context.typography.stampMedia(
          texts: <String>[date, ?place],
          videoWidth: width,
          canvas: format,
          size: stamp.size,
        );
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: OsdMotion.d(context, OsdMotion.fast),
                switchInCurve: OsdMotion.fastCurve,
                switchOutCurve: OsdMotion.fastCurve,
                layoutBuilder: (Widget? current, List<Widget> previous) =>
                    Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: <Widget>[...previous, ?current],
                    ),
                child: Stack(
                  key: ValueKey<StampFormat>(stamp.format),
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(
                      left: written ? margin : null,
                      bottom: written ? margin : null,
                      right: written ? null : margin,
                      top: written ? null : margin,
                      child: AnimatedStampText(
                        date,
                        key: dateKey,
                        style: style,
                        color: color,
                        outline: stamp.outline,
                        outlineWidth: outlineWidth,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: margin,
              bottom: margin,
              child: StampAppear(
                alignment: Alignment.bottomRight,
                child: place == null
                    ? null
                    : AnimatedStampText(
                        place,
                        key: placeKey,
                        style: style,
                        color: color,
                        outline: stamp.outline,
                        outlineWidth: outlineWidth,
                        textAlign: TextAlign.end,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
