import 'dart:async';

import 'package:one_second_diary/core/platform/free_space_gateway.dart';

/// A [FreeSpaceGateway] with [free] bytes free (null: unknown). With
/// [hold] set, each answer waits until the test calls [answer].
final class FakeFreeSpaceGateway implements FreeSpaceGateway {
  FakeFreeSpaceGateway({this.free});

  int? free;

  bool hold = false;

  final List<Completer<int?>> _waiting = <Completer<int?>>[];

  /// Answers the questions waiting with [free].
  void answer() {
    for (final Completer<int?> question in _waiting) {
      question.complete(free);
    }
    _waiting.clear();
  }

  @override
  Future<int?> freeBytes() {
    if (!hold) return Future<int?>.value(free);
    final Completer<int?> question = Completer<int?>();
    _waiting.add(question);
    return question.future;
  }
}
