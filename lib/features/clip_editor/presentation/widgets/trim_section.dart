import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length_format.dart';
import 'package:one_second_diary/features/clip_editor/domain/quick_cuts.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/filmstrip_trimmer.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/trim_readout.dart';
import 'package:one_second_diary/shared/widgets/controls/quick_cut_chip_row.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_skeleton_block.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The trim block under the preview: the saved length, the filmstrip with
/// its window, and the quick cuts.
///
/// Only this block and the readout rebuild while the window is dragged.
class TrimSection extends StatelessWidget {
  const TrimSection({super.key});

  /// The strip, still, when the source cannot be played.
  static const Key stillStripKey = Key('trimSection.stillStrip');

  @override
  Widget build(BuildContext context) =>
      BlocSelector<EditClipCubit, EditClipState, _Trim>(
        selector: (EditClipState state) => (
          path: state.args.source.path,
          trim: state.trim,
          savedLengthMs: state.savedLengthMs,
          aspectRatio: state.sourceAspectRatio,
          trimming: state.trimming,
          saving: state.saving,
          unplayable: state.status == EditClipStatus.unplayable,
        ),
        builder: (BuildContext context, _Trim view) {
          final EditClipCubit editor = context.read<EditClipCubit>();
          final TrimSelection? trim = view.trim;
          final double? aspectRatio = view.aspectRatio;
          final ClipLengthFormat format = ClipLengthFormat.of(
            Localizations.localeOf(context).toString(),
          );
          return Padding(
            padding: const EdgeInsets.only(top: OsdSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: OsdSpace.s10,
              children: <Widget>[
                Visibility.maintain(
                  visible: view.savedLengthMs != null,
                  child: TrimReadout(lengthMs: view.savedLengthMs ?? 0),
                ),
                if (view.unplayable)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OsdSpace.pageGutter,
                    ),
                    child: SizedBox(
                      key: stillStripKey,
                      height: FilmstripTrimmer.height,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.colors.c2,
                          borderRadius: BorderRadius.circular(OsdRadius.r10),
                        ),
                      ),
                    ),
                  )
                else if (trim == null || aspectRatio == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: OsdSpace.pageGutter,
                    ),
                    child: OsdSkeletonBlock(
                      width: double.infinity,
                      height: FilmstripTrimmer.height,
                      radius: OsdRadius.r10,
                      effect: OsdSkeletonEffect.pulse,
                    ),
                  )
                else
                  FilmstripTrimmer(
                    sourcePath: view.path,
                    trim: trim,
                    aspectRatio: aspectRatio,
                    trimming: view.trimming,
                    saving: view.saving,
                    onTrimStarted: editor.trimStarted,
                    onMoved: editor.windowMoved,
                    onStartDragged: editor.startDragged,
                    onEndDragged: editor.endDragged,
                    onTrimEnded: editor.trimEnded,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OsdSpace.pageGutter,
                  ),
                  // Media order: the chips run left to right in RTL too.
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: QuickCutChipRow(
                      values: <double>[
                        for (final int cut in QuickCuts.lengthsMs) cut / 1000,
                      ],
                      selected: switch (trim?.quickCutMs) {
                        final int cut => cut / 1000,
                        null => null,
                      },
                      maxSeconds: _longestCutSeconds(trim),
                      onSelected: (double seconds) =>
                          editor.quickCut((seconds * 1000).round()),
                      semanticsLabel: (double seconds) =>
                          Strings.saveVideoQuickCutSemantics(
                            seconds,
                            format: format.secondsFormat,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

  /// The longest quick cut on offer, in seconds: the source's length to
  /// the ms, or none while it loads or when it is locked.
  static double _longestCutSeconds(TrimSelection? trim) =>
      trim == null || trim.locked ? 0 : trim.sourceMs / 1000;
}

/// What the trim block shows.
typedef _Trim = ({
  String path,
  TrimSelection? trim,
  int? savedLengthMs,
  double? aspectRatio,
  bool trimming,
  bool saving,
  bool unplayable,
});
