import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/launch/media_start_gate.dart';
import 'package:one_second_diary/app/wiring/legacy_counter_wiring.dart';
import 'package:one_second_diary/app/wiring/library_wiring.dart';
import 'package:one_second_diary/app/wiring/reminder_plan_wiring.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_key.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';

import '../../support/support.dart';

/// Launch-order tests write every observable step into one journal, so the
/// order across services can be asserted.

/// The real preference store, journaling `prefs.<key>` for each write.
class JournalingPrefsStore extends PrefsStore {
  JournalingPrefsStore({required super.preferences, required this.journal});

  final List<String> journal;

  @override
  Future<void> write<T>(PrefKey<T> key, T value) {
    journal.add('prefs.${key.name}');
    return super.write(key, value);
  }
}

/// Whether [folder] holds anything (the launch sweeps the scratch folder).
String contentOf(String folder) {
  final Directory directory = Directory(folder);
  return directory.existsSync() && directory.listSync().isNotEmpty
      ? 'full'
      : 'empty';
}

/// A media engine that journals `engine.init`, with the state of the
/// scratch folder at that moment: `init()` empties it, so the launch must
/// have swept it first.
class JournalingMediaEngine extends FakeMediaEngine {
  JournalingMediaEngine({required this.paths, required this.journal})
    : super(scratchDir: paths.scratchDir);

  final AppPaths paths;
  final List<String> journal;

  @override
  Future<void> init() {
    journal.add('engine.init (scratch ${contentOf(paths.scratchDir)})');
    return super.init();
  }
}

/// The launch chain's publisher: journals `publisher.purgeTrash`, with the
/// state of the scratch folder (the sweep comes after it).
class JournalingMediaPublisher extends Fake implements MediaPublisher {
  JournalingMediaPublisher({required this.paths, required this.journal});

  final AppPaths paths;
  final List<String> journal;

  @override
  Future<void> purgeTrash() async {
    journal.add(
      'publisher.purgeTrash (scratch ${contentOf(paths.scratchDir)})',
    );
  }
}

class JournalingReminderPlan extends Fake implements ReminderPlanWiring {
  JournalingReminderPlan({required this.journal});

  final List<String> journal;

  @override
  Future<void> start() async => journal.add('reminderPlan.start');
}

class JournalingLibrary extends Fake implements LibraryWiring {
  JournalingLibrary({required this.journal});

  final List<String> journal;

  @override
  void start() => journal.add('library.start');
}

class JournalingCounters extends Fake implements LegacyCounterWiring {
  JournalingCounters({required this.journal});

  final List<String> journal;

  @override
  void start() => journal.add('counters.start');
}

/// A media store that moves real files (`onDisk`) and journals each call.
class JournalingMediaStore extends FakeMediaStoreGateway {
  JournalingMediaStore.onDisk(super.paths, {required this.journal})
    : super.onDisk();

  final List<String> journal;

  @override
  Future<bool> publish({required String tempFilePath, required String album}) {
    journal.add('mediaStore.publish');
    return super.publish(tempFilePath: tempFilePath, album: album);
  }

  @override
  Future<bool> delete({required String absolutePath, required String album}) {
    journal.add('mediaStore.delete');
    return super.delete(absolutePath: absolutePath, album: album);
  }
}

/// The media start gate, journaling `mediaGate.open`.
class JournalingMediaStartGate extends MediaStartGate {
  JournalingMediaStartGate({required this.journal});

  final List<String> journal;

  @override
  void open() {
    journal.add('mediaGate.open');
    super.open();
  }
}
