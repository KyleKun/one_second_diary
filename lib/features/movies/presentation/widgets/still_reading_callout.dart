import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_tints.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// "Still reading your videos", under the confirmation's callout, while the
/// movie has a tag filter and the clips' metadata is still being read (after a
/// reinstall a clip is untagged until read): the count may still change.
class StillReadingCallout extends StatelessWidget {
  const StillReadingCallout({super.key});

  static const Key calloutKey = Key('stillReadingCallout.callout');

  @override
  Widget build(BuildContext context) {
    final bool shown = context.select<CreateMovieCubit, bool>(
      (CreateMovieCubit flow) =>
          flow.state.isReadingClips &&
          (flow.state.draft?.tags.isNotEmpty ?? false),
    );
    final TextStyle bold = TextStyle(
      fontWeight: context.typography.label14Strong.fontWeight,
    );
    return AnimatedSize(
      duration: OsdMotion.d(context, OsdMotion.standard),
      curve: OsdMotion.curve(context, OsdMotion.standardCurve),
      alignment: Alignment.topCenter,
      child: shown
          ? Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Semantics(
                liveRegion: true,
                child: OsdCallout.accent(
                  key: calloutKey,
                  icon: OsdIcons.sell,
                  accent: context.colors.purple,
                  tint: OsdTints.purpleTint16,
                  lines: <InlineSpan>[
                    TextSpan(text: Strings.movieStillReadingTitle, style: bold),
                    TextSpan(text: Strings.movieStillReadingBody),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
