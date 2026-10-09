import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clip_editor/domain/recorded_tier.dart';
import 'package:one_second_diary/features/clip_editor/presentation/clip_canvas.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/date_stamp_card.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_profile_card.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/framing_card.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/mute_card.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/tags_card.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/zoom_card.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The General tab: the profile card over the framing card, the date-stamp
/// card and the tags card.
///
/// When the profile's canvas is not the source's shape, a note under the
/// profile says the clip will be fitted to it (the export pads a portrait
/// video into a landscape canvas and crops a landscape one into a portrait
/// canvas), unless the clip is framed for that canvas. A photo's shape is
/// known once the preview decoded it. A recording the camera made below
/// the profile's tier gets a note too ("Recorded at 1080p", once the
/// file's size is probed): the clip is saved in the profile's format,
/// scaled up.
class GeneralTab extends StatelessWidget {
  const GeneralTab({super.key});

  static const Key fitNoteKey = Key('generalTab.fitNote');

  static const Key recordedAtNoteKey = Key('generalTab.recordedAtNote');

  @override
  Widget build(BuildContext context) {
    final ProfileKey key = context.select(
      (EditClipCubit editor) => editor.state.draft.profile,
    );
    final double? aspectRatio = context.select(
      (EditClipCubit editor) => editor.state.sourceAspectRatio,
    );
    final ClipFormat format = context.select(
      (ProfilesCubit profiles) => ClipCanvas.formatOf(profiles.state, key),
    );
    final VideoOrientation canvas = format.orientation;
    final VideoOrientation? source = switch (aspectRatio) {
      null => null,
      > 1 => VideoOrientation.landscape,
      < 1 => VideoOrientation.portrait,
      _ => null,
    };
    final bool framed = context.select(
      (EditClipCubit editor) => editor.state.draft.frameFor(canvas) != null,
    );
    final bool fitted = source != null && source != canvas && !framed;
    // The probed file says what the camera recorded; the hand-off's size
    // only says the source is a recording (`RecordedTier.noted`).
    final ResolutionTier? recordedTier = context.select(
      (EditClipCubit editor) => RecordedTier.noted(
        recording: editor.state.args.recordedSize != null,
        source: editor.state.sourceSize,
        format: format,
      ),
    );
    final String? recordedAt = recordedTier == null
        ? null
        : Strings.recordedAt(tier: _tierLabel(recordedTier));
    final TextStyle note = context.typography.caption13.copyWith(
      color: context.colors.mu,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const EditClipProfileCard(),
            AnimatedSize(
              duration: OsdMotion.d(context, OsdMotion.standard),
              curve: OsdMotion.curve(context, OsdMotion.standardCurve),
              alignment: AlignmentDirectional.topStart,
              child: fitted
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: 6,
                        start: 4,
                        end: 4,
                      ),
                      child: Text(
                        Strings.saveVideoOrientationFitNote(
                          orientation: canvas == VideoOrientation.portrait
                              ? Strings.cameraOrientationWordPortrait
                              : Strings.cameraOrientationWordLandscape,
                        ),
                        key: fitNoteKey,
                        style: note,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            AnimatedSize(
              duration: OsdMotion.d(context, OsdMotion.standard),
              curve: OsdMotion.curve(context, OsdMotion.standardCurve),
              alignment: AlignmentDirectional.topStart,
              child: recordedAt != null
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: 6,
                        start: 4,
                        end: 4,
                      ),
                      child: Text(
                        recordedAt,
                        key: recordedAtNoteKey,
                        style: note,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
        const FramingCard(),
        const DateStampCard(),
        const TagsCard(),
        const MuteCard(),
        const ZoomCard(),
      ],
    );
  }

  /// The tier's name as the quality picker shows it.
  static String _tierLabel(ResolutionTier tier) => switch (tier) {
    ResolutionTier.p720 => Strings.qualityTier720,
    ResolutionTier.p1080 => Strings.qualityTier1080,
    ResolutionTier.p1440 => Strings.qualityTier1440,
    ResolutionTier.p2160 => Strings.qualityTier2160,
  };
}
