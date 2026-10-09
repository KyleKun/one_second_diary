import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/movie_render_request.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

import '../temp_storage.dart';
import 'fake_media_engine.dart';

MovieClip _clip(String path) => MovieClip(
  path: path,
  durationMs: 1500,
  isOsdV15: true,
  hasAudio: true,
  hasSubtitleStream: false,
  width: 1920,
  height: 1080,
  codec: 'h264',
);

MovieRenderRequest _movie(String outputPath, {int clips = 2}) =>
    MovieRenderRequest(
      clips: <MovieClip>[
        for (var day = 1; day <= clips; day++) _clip('/v/2024-01-0$day.mp4'),
      ],
      format: const ClipFormat.legacy(VideoOrientation.landscape),
      outputPath: outputPath,
      title: null,
      comment: null,
    );

void main() {
  // MediaEngine.renderMovie (lib/core/media/media_engine.dart): fewer than
  // two clips or an existing output is an ArgumentError before any work
  // (movies are never overwritten), and a cancel ends the stream with a
  // CancelledException and no file. Movie tests rely on the fake for both.
  test('the fake renderMovie keeps the real contract: no overwrite, no '
      'one-clip movie, and a cancel leaves no file', () async {
    final String scratch = '${(await createTempRoot()).path}/scratch';
    final FakeMediaEngine engine = FakeMediaEngine(scratchDir: scratch);
    final String taken = (File(
      '$scratch/taken.mp4',
    )..createSync(recursive: true)).path;

    await expectLater(
      engine.renderMovie(_movie('$scratch/one.mp4', clips: 1)).toList(),
      throwsArgumentError,
    );
    await expectLater(
      engine.renderMovie(_movie(taken)).toList(),
      throwsArgumentError,
    );
    expect(File('$scratch/one.mp4').existsSync(), isFalse);

    final String output = '$scratch/movie.mp4';
    final CancelToken token = CancelToken();
    engine.holdMovie = true;
    final List<MovieRenderEvent> seen = <MovieRenderEvent>[];
    final Completer<Object> failed = Completer<Object>();
    engine
        .renderMovie(_movie(output), cancelToken: token)
        .listen(seen.add, onError: failed.complete);
    await pumpEventQueue();
    token.cancel();

    expect(await failed.future, isA<CancelledException>());
    expect(seen.whereType<MovieCompleted>(), isEmpty);
    expect(File(output).existsSync(), isFalse);
  });
}
