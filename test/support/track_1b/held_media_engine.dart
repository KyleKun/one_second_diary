import 'dart:async';

import 'package:one_second_diary/core/media/types/clip_probe.dart';

import '../fakes/fake_media_engine.dart';

/// A [FakeMediaEngine] that records subtitle reads and, while [hold] is
/// true, keeps each probe in flight until [releaseProbe] is called. It
/// shows which probes have started ([probedPaths]) and how many run at once
/// ([inFlight], [mostInFlight]), for the metadata backfill's
/// one-probe-at-a-time and pause rules.
class HeldMediaEngine extends FakeMediaEngine {
  HeldMediaEngine({required super.scratchDir});

  bool hold = false;
  final List<Completer<void>> _held = <Completer<void>>[];

  /// Paths `readSubtitles` was asked for, in order.
  final List<String> subtitleReads = <String>[];

  int inFlight = 0;
  int mostInFlight = 0;

  /// Probes waiting for [releaseProbe].
  int get heldProbes => _held.length;

  /// Lets the oldest held probe answer.
  void releaseProbe() => _held.removeAt(0).complete();

  @override
  Future<ClipProbe> probe(String path) async {
    inFlight++;
    if (inFlight > mostInFlight) mostInFlight = inFlight;
    try {
      final Future<ClipProbe> answer = super.probe(path);
      if (hold) {
        final Completer<void> gate = Completer<void>();
        _held.add(gate);
        await gate.future;
      }
      return await answer;
    } finally {
      inFlight--;
    }
  }

  @override
  Future<String> readSubtitles(String path) {
    subtitleReads.add(path);
    return super.readSubtitles(path);
  }
}
