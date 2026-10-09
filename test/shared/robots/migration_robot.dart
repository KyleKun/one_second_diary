import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/launch/legacy_migration_dialog.dart';

import '../harness/settle.dart';

/// The Android folder migration's dialog.
class MigrationRobot {
  MigrationRobot(this.tester);

  final WidgetTester tester;

  /// The dialog shows the outcome [title] ("Success" or "Error").
  void expectOutcome(String title) {
    expect(find.byType(LegacyMigrationDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LegacyMigrationDialog),
        matching: find.text(title),
      ),
      findsOneWidget,
    );
  }

  Future<void> acknowledge() async {
    await tester.tap(find.byKey(LegacyMigrationDialog.okKey));
    await settle(tester);
  }

  void expectClosed() =>
      expect(find.byType(LegacyMigrationDialog), findsNothing);
}
