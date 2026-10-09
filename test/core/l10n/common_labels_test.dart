import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';

void main() {
  Future<List<String>> labelsIn(WidgetTester tester, Locale locale) async {
    late CommonLabels labels;
    await tester.pumpWidget(
      Localizations(
        locale: locale,
        delegates: GlobalMaterialLocalizations.delegates,
        child: Builder(
          builder: (BuildContext context) {
            labels = CommonLabels.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return <String>[
      labels.back,
      labels.close,
      labels.delete,
      labels.cancel,
      labels.continueAction,
      labels.selectAll,
      labels.previousMonth,
      labels.nextMonth,
      labels.today,
    ];
  }

  testWidgets('say what the removed OSD keys said in English, translated in '
      'the app languages', (WidgetTester tester) async {
    expect(await labelsIn(tester, const Locale('en')), <String>[
      'Back',
      'Close',
      'Delete',
      'Cancel',
      'Continue',
      'Select all',
      'Previous month',
      'Next month',
      'Today',
    ]);
    expect(await labelsIn(tester, const Locale('de')), <String>[
      'Zurück',
      'Schließen',
      'Löschen',
      'Abbrechen',
      'Weiter',
      'Alle auswählen',
      'Vorheriger Monat',
      'Nächster Monat',
      'Heute',
    ]);
    expect((await labelsIn(tester, const Locale('pt')))[3], 'Cancelar');
  });
}
