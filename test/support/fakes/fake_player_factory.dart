import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/player_factory.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';

import 'fake_player_handle.dart';

/// A [PlayerFactory] that creates [FakePlayerHandle]s and keeps them in
/// [created], so tests can check how many players are alive, which were
/// disposed, and drive them.
///
/// New handles get [duration] and [aspectRatio]; paths in [failingPaths]
/// fail to initialise; with [holdInitialize] they wait for
/// `FakePlayerHandle.completeInitialize`.
class FakePlayerFactory extends Fake implements PlayerFactory {
  final List<FakePlayerHandle> created = <FakePlayerHandle>[];
  final Set<String> failingPaths = <String>{};
  Duration duration = const Duration(seconds: 2);
  double aspectRatio = 16 / 9;
  bool holdInitialize = false;

  /// Handles not disposed yet.
  List<FakePlayerHandle> get alive => <FakePlayerHandle>[
    for (final FakePlayerHandle handle in created)
      if (!handle.isDisposed) handle,
  ];

  @override
  PlayerHandle create(String path, {required bool mixWithOthers}) {
    final FakePlayerHandle handle = FakePlayerHandle(
      path: path,
      mixWithOthers: mixWithOthers,
      duration: duration,
      aspectRatio: aspectRatio,
      failInitialize: failingPaths.contains(path),
      holdInitialize: holdInitialize,
    );
    created.add(handle);
    return handle;
  }
}
