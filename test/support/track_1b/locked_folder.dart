import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sets [folder] to [mode] (`000`: unreadable, `555`: read-only) until the
/// test ends, and says whether this user is actually refused.
///
/// Root reads and writes any folder whatever its mode, so in a container
/// that runs tests as root the refusal a test relies on never comes. Such a
/// test skips itself instead of failing:
/// `if (!await lockFolder(path)) return;`.
Future<bool> lockFolder(String folder, {String mode = '000'}) async {
  await Process.run('chmod', <String>[mode, folder]);
  addTearDown(() => Process.run('chmod', <String>['755', folder]));
  final bool refused = mode == '000'
      ? _refuses(() => Directory(folder).listSync())
      : _refuses(
          () => (File('$folder/.osd_lock_probe')..createSync()).deleteSync(),
        );
  if (!refused) {
    markTestSkipped('This user ignores folder mode $mode (root?).');
  }
  return refused;
}

bool _refuses(void Function() attempt) {
  try {
    attempt();
    return false;
  } on FileSystemException {
    return true;
  }
}
