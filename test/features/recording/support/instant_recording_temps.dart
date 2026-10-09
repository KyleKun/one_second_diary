import 'dart:io';

import 'package:one_second_diary/features/recording/data/recording_temps.dart';

import '../../../support/support.dart';

/// [RecordingTemps] that deletes at once, so a bloc test in fake time (where
/// real file IO never completes) sees a dropped recording gone.
class InstantRecordingTemps extends RecordingTemps {
  InstantRecordingTemps() : super(logger: memoryLogger(MemoryLogSink()));

  @override
  Future<void> discard(String path) async {
    final File file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}
