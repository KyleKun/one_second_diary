import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/features/clips/data/import_processor.dart';
import 'package:one_second_diary/features/clips/domain/imported_video.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_imports_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The processing sheet's state: lists the foreign videos of every profile,
/// keeps the two remembered choices and runs "Process N videos" one by one
/// through the [ImportProcessor]. [cancel] stops after the file in flight,
/// keeping what was done. Screen-scoped: [load] once, then [start].
class ProcessImportsCubit extends Cubit<ProcessImportsState> {
  ProcessImportsCubit({required ImportProcessor processor})
    : _processor = processor,
      super(
        ProcessImportsState(
          stage: ProcessImportsStage.listing,
          choices: processor.choices,
        ),
      );

  final ImportProcessor _processor;

  CancelToken? _cancel;

  /// Lists the foreign videos of [profiles] and reads the lengths the
  /// cache does not know, then the Originals folder's size.
  Future<void> load(Iterable<ProfileKey> profiles) async {
    final List<ImportedVideo> found = _processor.candidates(profiles);
    emit(state.copyWith(videos: found));
    final List<ImportedVideo> timed = await _processor.withDurations(found);
    if (isClosed) return;
    emit(
      state.copyWith(
        stage: ProcessImportsStage.ready,
        videos: timed,
        originalsBytes: await _processor.originalsSizeBytes(),
      ),
    );
  }

  /// "Keep the whole video" (true) or "Keep the first N s", remembered.
  Future<void> setKeepWhole({required bool keepWhole}) =>
      _remember(state.choices.copyWith(keepWhole: keepWhole));

  /// The date stamp on or off, remembered.
  Future<void> setDateStamp({required bool dateStamp}) =>
      _remember(state.choices.copyWith(dateStamp: dateStamp));

  Future<void> _remember(ImportChoices choices) async {
    if (state.stage == ProcessImportsStage.running) return;
    emit(state.copyWith(choices: choices));
    await _processor.rememberChoices(choices);
  }

  /// "Process N videos": runs the list with the choices; [stampText] is
  /// the day's stamp in the sheet's language.
  Future<void> start({required StampTextOf stampText}) async {
    if (!state.canStart) return;
    final CancelToken cancel = CancelToken();
    _cancel = cancel;
    emit(state.copyWith(stage: ProcessImportsStage.running, done: 0));
    try {
      await for (final ImportEvent event in _processor.process(
        state.videos,
        choices: state.choices,
        stampText: stampText,
        cancelToken: cancel,
      )) {
        if (isClosed) return;
        switch (event) {
          case ImportProgress(:final int index, :final double fraction):
            emit(state.copyWith(done: index, fraction: fraction));
          case ImportVideoDone(:final ImportedVideo video):
          case ImportVideoSkipped(:final ImportedVideo video):
            emit(
              state.copyWith(
                done: state.videos.indexOf(video) + 1,
                fraction: 0,
              ),
            );
          case ImportFinished(:final ImportReport report):
            emit(
              state.copyWith(
                stage: ProcessImportsStage.done,
                report: report,
                originalsBytes: await _processor.originalsSizeBytes(),
              ),
            );
        }
      }
    } on Object {
      // The processor logs what failed; the sheet shows an empty report.
      if (!isClosed) {
        emit(
          state.copyWith(
            stage: ProcessImportsStage.done,
            report: ImportReport.nothing,
          ),
        );
      }
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  /// Stops after the video in flight; what was done is kept.
  void cancel() => _cancel?.cancel();

  /// "Delete originals" (confirmed by the user): empties the folder.
  Future<void> deleteOriginals() async {
    await _processor.deleteOriginals();
    if (isClosed) return;
    emit(state.copyWith(originalsBytes: await _processor.originalsSizeBytes()));
  }

  @override
  Future<void> close() {
    _cancel?.cancel();
    return super.close();
  }
}
