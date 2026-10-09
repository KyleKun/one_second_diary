import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';

/// A [BugReportService] that records the reports asked for ([bodies]) and
/// answers [outcome]; with [hold], each waits until [answer].
class FakeBugReports extends Fake implements BugReportService {
  final List<String> bodies = <String>[];

  BugReportOutcome outcome = BugReportOutcome.composerOpened;

  bool hold = false;

  final List<Completer<BugReportOutcome>> _waiting =
      <Completer<BugReportOutcome>>[];

  /// Answers the reports waiting with [outcome].
  void answer() {
    for (final Completer<BugReportOutcome> report in _waiting) {
      report.complete(outcome);
    }
    _waiting.clear();
  }

  @override
  Future<BugReportOutcome> reportError({required String body}) {
    bodies.add(body);
    if (!hold) return Future<BugReportOutcome>.value(outcome);
    final Completer<BugReportOutcome> report = Completer<BugReportOutcome>();
    _waiting.add(report);
    return report.future;
  }
}
