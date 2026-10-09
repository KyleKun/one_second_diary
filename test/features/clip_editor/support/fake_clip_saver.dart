import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/data/clip_saver.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_render_plan.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// What the editor asked a [FakeClipSaver] to save.
final class SaveCall extends Equatable {
  const SaveCall({
    required this.request,
    required this.source,
    required this.profile,
    required this.day,
    required this.mode,
  });

  final ClipRenderRequest request;
  final ClipSource source;
  final ProfileKey profile;
  final LocalDay day;
  final ClipSaveMode mode;

  @override
  List<Object?> get props => <Object?>[request, source, profile, day, mode];
}

/// The clip January 5 gets when a [FakeClipSaver] saves it.
final SavedClip savedJanuary5 = SavedClip(
  ref: ClipRef(profile: ProfileKey.defaultProfile, relPath: '2024-01-05.mp4'),
  undoToken: const PublishedUndo(relPath: '2024-01-05.mp4'),
);

/// A [ClipSaver] the test drives: each save waits until the test reports
/// its [progress], says it is [publishing], and [finish]es or [fail]s it.
/// A cancelled token ends the save waiting with a [CancelledException],
/// as the engine does once its session stopped. [discarded] records the
/// sources the editor gave up. [sizes] is what a probe says of a source's
/// size (nothing, unless the test says) and [transfers] of its colour
/// transfer (SDR unless the test says).
class FakeClipSaver extends Fake implements ClipSaver {
  final List<SaveCall> calls = <SaveCall>[];
  final List<ClipSource> discarded = <ClipSource>[];
  final Map<String, SourceSize> sizes = <String, SourceSize>{};
  final Map<String, String> transfers = <String, String>{};

  @override
  Future<SourceSize?> sourceSize(String path) async => sizes[path];

  @override
  Future<SourceFacts?> sourceFacts(String path) async {
    final SourceSize? size = sizes[path];
    if (size == null) return null;
    return (
      width: size.width,
      height: size.height,
      colorTransfer: transfers[path],
    );
  }

  Completer<SavedClip>? _running;
  void Function(double fraction)? _onProgress;
  void Function()? _onPublishing;

  /// Whether a save waits for the test.
  bool get running => _running != null && !_running!.isCompleted;

  @override
  Future<SavedClip> save({
    required ClipRenderRequest request,
    required ClipSource source,
    required ProfileKey profile,
    required LocalDay day,
    required ClipSaveMode mode,
    required CancelToken cancelToken,
    required void Function(double fraction) onProgress,
    required void Function() onPublishing,
  }) {
    calls.add(
      SaveCall(
        request: request,
        source: source,
        profile: profile,
        day: day,
        mode: mode,
      ),
    );
    final Completer<SavedClip> running = _running = Completer<SavedClip>();
    _onProgress = onProgress;
    _onPublishing = onPublishing;
    unawaited(
      cancelToken.whenCancelled.then((_) {
        if (!running.isCompleted) {
          running.completeError(const CancelledException('Cancelled'));
        }
      }),
    );
    return running.future;
  }

  /// The render reports [fraction] done.
  void progress(double fraction) => _onProgress!(fraction);

  /// The render is done; the clip is being filed.
  void publishing() => _onPublishing!();

  /// The save ends with [saved].
  void finish([SavedClip? saved]) => _running!.complete(saved ?? savedJanuary5);

  /// The save fails with [error].
  void fail([Object? error]) => _running!.completeError(
    error ??
        const VideoProcessingException(
          'Saving 2024-01-05.mp4 failed',
          returnCode: 1,
          logTail: '',
        ),
  );

  @override
  Future<void> discardSource(ClipSource source) async => discarded.add(source);
}
