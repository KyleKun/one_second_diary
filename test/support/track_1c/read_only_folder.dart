import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Makes [folder] read-only (mode 555) until the test ends, the way Android
/// 11+ treats a file a previous install made: it can be read, but unlinking
/// it fails with EACCES. Returns false when this user can still write
/// there (root), so the caller can mark the test skipped.
bool makeReadOnly(String folder) {
  Process.runSync('chmod', <String>['555', folder]);
  addTearDown(() => Process.runSync('chmod', <String>['755', folder]));
  final File probe = File('$folder/.read_only_probe');
  try {
    probe.writeAsBytesSync(<int>[0]);
    probe.deleteSync();
    return false;
  } on FileSystemException {
    return true;
  }
}
