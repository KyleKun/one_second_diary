// The subtitles sheet, shared by the clip editor's Subtitles tab, the Diary
// and the viewer and Today's Edit sheet.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/clips/presentation/subtitles/subtitle_sheet.dart';

import '../../../shared/harness/settle.dart';
import '../../../shared/robots/app_robot.dart';
import '../../../support/support.dart';

void main() {
  late AppRobot app;

  group('with a save of its own (a saved clip)', () {
    testWidgets('a save that fails closes the sheet and fails with the text, '
        'so the caller can offer to try again', (tester) async {
      Object? failure;
      app = await AppRobot.launch(tester, prefs: legacyPrefs());
      unawaited(
        SubtitleSheet.show(
          app.shell.pageElement(AppRoute.today),
          text: 'Old',
          onSave: (String text) async => throw StateError('no space'),
        ).then<void>((_) {}, onError: (Object error) => failure = error),
      );
      await settle(tester);

      await app.subtitleSheet.enterText('New');
      await app.subtitleSheet.tapSave();

      app.subtitleSheet.expectClosed();
      expect(
        failure,
        isA<SubtitleSaveFailed>()
            .having((SubtitleSaveFailed f) => f.text, 'text', 'New')
            .having((SubtitleSaveFailed f) => f.error, 'error', isStateError),
      );
    });
  });
}
