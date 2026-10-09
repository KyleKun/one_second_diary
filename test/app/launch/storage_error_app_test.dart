import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/launch/storage_error_app.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableLevels = [];
  });

  // rootBundle caches each loaded file as a Future created in that test's
  // fake-async zone; a later test awaiting it would never resume.
  tearDown(rootBundle.clear);

  Future<void> pump(
    WidgetTester tester, {
    String? legacyVideosPath = '/data/user/0/app/DCIM/OneSecondDiary/',
    bool darkMode = true,
  }) async {
    await tester.pumpWidget(
      StorageErrorApp(
        language: AppLanguage.en,
        darkMode: darkMode,
        legacyVideosPath: legacyVideosPath,
      ),
    );
    await tester.pumpAndSettle();
  }

  // Older installs then wrote the diary into private storage, which an
  // uninstall deletes; the user must learn where those clips are.
  testWidgets('says the diary cannot be opened and where v1.7 kept clips '
      'then', (WidgetTester tester) async {
    await pump(tester);

    expect(find.text("Can't open your diary"), findsOneWidget);
    expect(
      find.textContaining('/data/user/0/app/DCIM/OneSecondDiary/'),
      findsOneWidget,
    );
  });

  testWidgets('leaves the folder out when it is not known', (
    WidgetTester tester,
  ) async {
    await pump(tester, legacyVideosPath: null);

    expect(find.text("Can't open your diary"), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('follows the stored theme', (WidgetTester tester) async {
    await pump(tester, darkMode: false);

    final BuildContext context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(context.colors, OsdColors.light);
  });
}
