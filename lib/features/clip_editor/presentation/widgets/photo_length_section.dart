import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length_format.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/trim_readout.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/shared/widgets/controls/quick_cut_chip_row.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// How long a photo is held, in the trimmer's place: the length, then a
/// chip per `SettingsRepository.photoDurationsMs`. A tap takes another
/// length and the next photo starts there too.
class PhotoLengthSection extends StatelessWidget {
  const PhotoLengthSection({super.key});

  @override
  Widget build(BuildContext context) {
    final int durationMs = context.select(
      (EditClipCubit editor) => switch (editor.state.draft.length) {
        HeldPhoto(:final int durationMs) => durationMs,
        _ => SettingsRepository.photoDurationsMs.first,
      },
    );
    final ClipLengthFormat format = ClipLengthFormat.of(
      Localizations.localeOf(context).toString(),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OsdSpace.pageGutter,
        OsdSpace.s12,
        OsdSpace.pageGutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: OsdSpace.s10,
        children: <Widget>[
          TrimReadout(lengthMs: durationMs),
          // Media order: the chips run left to right in RTL too.
          Directionality(
            textDirection: TextDirection.ltr,
            child: QuickCutChipRow(
              values: <double>[
                for (final int length in SettingsRepository.photoDurationsMs)
                  length / 1000,
              ],
              selected: durationMs / 1000,
              onSelected: (double seconds) => context
                  .read<EditClipCubit>()
                  .photoDurationChanged((seconds * 1000).round()),
              semanticsLabel: (double seconds) =>
                  Strings.saveVideoClipLengthSemantics(
                    seconds,
                    format: format.secondsFormat,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
