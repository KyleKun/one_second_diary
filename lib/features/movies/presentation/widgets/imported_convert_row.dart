import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_import_flow.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Under the confirmation's callouts: "12 videos will be converted first (about
/// 4 min)" when the cache says some of the movie's clips are not in the
/// profile's format, with "Process them now", which opens the processing sheet.
class ImportedConvertRow extends StatelessWidget {
  const ImportedConvertRow({super.key});

  static const Key calloutKey = Key('importedConvertRow.callout');

  static const Key processKey = Key('importedConvertRow.process');

  @override
  Widget build(BuildContext context) {
    final (int clips, int durationMs, ProfileKey profile) = context
        .select<CreateMovieCubit, (int, int, ProfileKey)>(
          (CreateMovieCubit flow) => (
            flow.state.foreignClips,
            flow.state.foreignDurationMs,
            flow.state.profile,
          ),
        );
    return AnimatedSize(
      duration: OsdMotion.d(context, OsdMotion.standard),
      curve: OsdMotion.curve(context, OsdMotion.standardCurve),
      alignment: Alignment.topCenter,
      child: clips == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Semantics(
                    liveRegion: true,
                    child: OsdCallout.neutral(
                      key: calloutKey,
                      text: Strings.movieImportedWillConvert(
                        clips,
                        time: MovieLabels.roughDuration(
                          ProcessImportFlow.timeFor(
                            context,
                            durationMs: durationMs,
                            profile: profile,
                          ),
                        ),
                        format: MovieLabels.numberFormat(context),
                      ),
                      kind: OsdCalloutKind.info,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: OsdTextButton(
                      key: processKey,
                      label: Strings.movieProcessNow,
                      hug: true,
                      onPressed: () =>
                          unawaited(ProcessImportFlow.showSheet(context)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
