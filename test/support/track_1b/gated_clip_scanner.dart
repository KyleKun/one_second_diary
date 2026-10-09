import 'dart:async';

import 'package:one_second_diary/features/clips/data/clip_scan.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// A real [ClipScanner] whose scans can be held in flight: while [hold] is
/// true a scan lists the disk at once but hands its result back only when
/// [releaseNext] is called. That reproduces a slow scan racing the app's own
/// writes or a second rescan request.
class GatedClipScanner extends ClipScanner {
  GatedClipScanner({required super.paths, required super.logger});

  bool hold = false;
  final List<Completer<void>> _held = <Completer<void>>[];

  /// Scans that have listed the disk and wait to be released.
  int get heldScans => _held.length;

  /// Lets the oldest held scan return its (by now possibly stale) result.
  void releaseNext() => _held.removeAt(0).complete();

  @override
  Future<ClipScan> scan(ProfileKey profile) async {
    final ClipScan result = await super.scan(profile);
    if (hold) {
      final Completer<void> gate = Completer<void>();
      _held.add(gate);
      await gate.future;
    }
    return result;
  }
}
