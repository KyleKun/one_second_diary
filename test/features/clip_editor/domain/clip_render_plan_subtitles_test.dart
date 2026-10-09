// The subtitle the editor saves reaches the clip whole, over the real media
// engine with ffmpeg faked. A player ends a cue at the first empty line, so
// an empty line inside the cue loses the rest of the subtitle. SrtCodec has
// its own tests (srt_codec_test.dart); these hold the editor's path to it:
// the plan's request, rendered by the engine.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/srt_codec.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_render_plan.dart';
import 'package:one_second_diary/features/clip_editor/domain/edit_clip_draft.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../support/support.dart';
import '../../../support/track_1a/media_engine_harness.dart';

void main() {
  late AppPaths paths;
  late MediaEngine engine;
  late VideoSource recording;

  /// The SRT of every render, read while ffmpeg "ran".
  late List<String> subtitleFiles;

  setUp(() async {
    paths = await createTestPaths();
    subtitleFiles = <String>[];
    final FakeFfmpegGateway ffmpeg = FakeFfmpegGateway()
      ..onExecute = (List<String> arguments) async {
        for (final String argument in arguments) {
          if (argument.endsWith('subtitles.srt')) {
            subtitleFiles.add(await File(argument).readAsString());
          }
        }
        final File output = File(arguments[arguments.length - 2]);
        await output.parent.create(recursive: true);
        await output.writeAsBytes(<int>[4, 2]);
      };
    engine = engineOver(ffmpeg: ffmpeg, paths: paths);
    final File video = File('${paths.temporaryDir}/REC_1.mp4');
    await video.create(recursive: true);
    await video.writeAsBytes(fakeVideoBytes);
    recording = VideoSource(
      path: video.path,
      ownership: ClipOwnership.cameraTemp,
    );
  });

  /// Renders what the editor's Save asks for a recording subtitled
  /// [subtitles], and returns the subtitle the clip got.
  Future<String> savedSubtitle(String subtitles) async {
    await engine.renderClip(
      ClipRenderPlan.of(
        source: recording,
        day: LocalDay(2024, 1, 5),
        mode: const AddClip(),
        draft: EditClipDraft(
          profile: ProfileKey.defaultProfile,
          length: TrimmedVideo(
            TrimSelection.initial(sourceMs: 4000).withLength(1000),
          ),
          stamp: const StampStyle(
            format: StampFormat.numeric,
            rgb: 0xFFFFFF,
            outline: true,
          ),
          location: const ClipLocation.off(),
          subtitles: subtitles,
        ),
        legacyStampFont: false,
        look: const ClipRenderLook(
          stampText: '01/05/2024',
          format: ClipFormat.legacy(VideoOrientation.landscape),
        ),
      ),
    );
    final String srt = subtitleFiles.single;
    // One cue: nothing after its text but the blank line that ends it.
    final String cue = srt.split('\r\n')[2];
    expect(cue.trimRight(), isNot(contains('\n\n')), reason: srt);
    return SrtCodec.decode(srt);
  }

  test('the subtitle reaches the clip whole: a first word over 45 '
      'characters keeps the words after it (E-5); an empty line in the text '
      'is dropped, the lines around it stay (E-6)', () async {
    const String word = 'Supercalifragilisticexpialidociously-extraordinary';

    expect(await savedSubtitle('$word morning'), '$word\nmorning');
    subtitleFiles.clear();
    expect(await savedSubtitle('Rain\n\nlater'), 'Rain\nlater');
  });
}
