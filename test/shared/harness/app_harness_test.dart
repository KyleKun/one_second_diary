import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';

import '../../support/support.dart';
import 'app_harness.dart';

/// The harness options journeys rely on: the phone, and the moment the app
/// starts.
void main() {
  /// This launch's log, named after the moment it started.
  Future<String> logOf(AppHarness harness, String fileName) async =>
      (await harness.tester.runAsync(() async {
        await sl<AppLogger>().flush();
        return File('${harness.paths.logsDir}/$fileName').readAsString();
      }))!;

  testWidgets('the app starts at the moment the journey picks', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await AppHarness.launch(
      tester,
      prefs: legacyPrefs(),
      now: DateTime(2024, 3, 1, 7, 30),
    );

    expect(harness.clock.now(), DateTime(2024, 3, 1, 7, 30));
    expect(
      (await harness.storedPrefs).getString('currentLogFile'),
      '2024-03-01_07-30-00.txt',
    );
  });

  testWidgets('an iPhone launch takes the iOS paths', (
    WidgetTester tester,
  ) async {
    final AppHarness harness = await AppHarness.launch(
      tester,
      prefs: legacyPrefs(),
      isIOS: true,
    );

    expect(
      await logOf(harness, '2024-01-05_10-00-00.txt'),
      contains('Encoding with ${VideoEncoder.videoToolbox.ffmpegName}'),
    );
  });
}
