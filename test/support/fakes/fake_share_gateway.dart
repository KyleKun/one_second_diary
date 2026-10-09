import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/share_gateway.dart';

/// A [ShareGateway] that records what was shared.
class FakeShareGateway extends Fake implements ShareGateway {
  /// Every `shareFiles` call's paths, in order.
  final List<List<String>> sharedFiles = <List<String>>[];

  /// Every `shareText` call's text, in order.
  final List<String> sharedTexts = <String>[];

  /// The origin passed to the last call.
  Rect? lastOrigin;

  @override
  Future<void> shareFiles(List<String> paths, {Rect? origin}) async {
    sharedFiles.add(List<String>.unmodifiable(paths));
    lastOrigin = origin;
  }

  @override
  Future<void> shareText(String text, {Rect? origin}) async {
    sharedTexts.add(text);
    lastOrigin = origin;
  }
}
