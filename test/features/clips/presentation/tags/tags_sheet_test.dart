// The tags sheet, shared by the clip editor's tags card, the Diary, the
// viewer, Memories and Today's Edit sheet.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_sheet.dart';

import '../../../../shared/harness/settle.dart';
import '../../../../shared/robots/app_robot.dart';
import '../../../../support/support.dart';

void main() {
  testWidgets('Enter adds the typed tag as a chip, a duplicate says so and is '
      'not added, a suggestion is added with a tap, and Save hands the '
      'caller the tags normalised', (tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    List<String>? saved;
    List<String>? completed;
    unawaited(
      TagsSheet.show(
        app.shell.pageElement(AppRoute.today),
        tags: <String>['kids'],
        suggestions: <String>['kids', 'Bread'],
        onSave: (List<String> tags) async => saved = tags,
      ).then((List<String>? tags) => completed = tags),
    );
    await settle(tester);
    app.tagsSheet.expectOpen();
    expect(app.tagsSheet.chips, <String>['kids']);

    await app.tagsSheet.addTag('trip');
    expect(app.tagsSheet.chips, <String>['kids', 'trip']);
    expect(app.tagsSheet.errorText, isNull);

    await app.tagsSheet.addTag('Trip');
    expect(app.tagsSheet.chips, <String>['kids', 'trip']);
    expect(app.tagsSheet.errorText, 'This video already has this tag');

    await app.tagsSheet.tapSuggestion('Bread');
    expect(app.tagsSheet.chips, <String>['kids', 'trip', 'Bread']);
    expect(app.tagsSheet.errorText, isNull);

    await app.tagsSheet.tapSave();

    app.tagsSheet.expectClosed();
    expect(saved, <String>['Bread', 'kids', 'trip']);
    expect(completed, <String>['Bread', 'kids', 'trip']);
  });

  testWidgets('Save is off until something changed, and a typed comma adds '
      'the tag like Enter', (tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    unawaited(
      TagsSheet.show(
        app.shell.pageElement(AppRoute.today),
        tags: const <String>[],
        suggestions: const <String>[],
      ),
    );
    await settle(tester);
    expect(app.tagsSheet.saveEnabled, isFalse);

    await app.tagsSheet.typeTag('bread,');
    await settle(tester);

    expect(app.tagsSheet.chips, <String>['bread']);
    expect(app.tagsSheet.saveEnabled, isTrue);
  });
}
