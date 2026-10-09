// "Report error" on a failure surface (the movie being made and the camera
// share this cubit): the user's mail app opens with the zipped logs, or the
// page says there is none, on every tap that finds none.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_cubit.dart';

import '../../../../shared/fakes/fake_bug_reports.dart';

void main() {
  late FakeBugReports reports;
  late ReportErrorCubit cubit;

  setUp(() {
    reports = FakeBugReports();
    cubit = ReportErrorCubit(reports: reports);
  });
  tearDown(() => cubit.close());

  test('a report goes to the mail app with the body the page gives; '
      'sending meanwhile, and a second tap does nothing; a mailto link '
      'opened counts as opened', () async {
    expect(cubit.state, ReportErrorStatus.idle);
    reports.hold = true;

    final Future<void> sending = cubit.report(body: 'What happened:');
    expect(cubit.state, ReportErrorStatus.sending);
    await cubit.report(body: 'What happened:');
    reports.answer();
    await sending;

    expect(reports.bodies, <String>['What happened:']);
    expect(cubit.state, ReportErrorStatus.opened);

    final ReportErrorCubit mailto = ReportErrorCubit(
      reports: FakeBugReports()..outcome = BugReportOutcome.mailtoOpened,
    );
    addTearDown(mailto.close);
    await mailto.report(body: 'x');
    expect(mailto.state, ReportErrorStatus.opened);
  });

  test('no mail app on the phone: said so, every time', () async {
    reports.outcome = BugReportOutcome.noMailApp;
    final List<ReportErrorStatus> states = <ReportErrorStatus>[];
    cubit.stream.listen(states.add);

    await cubit.report(body: 'x');
    await cubit.report(body: 'x');
    await pumpEventQueue();

    expect(states, <ReportErrorStatus>[
      ReportErrorStatus.sending,
      ReportErrorStatus.noMailApp,
      ReportErrorStatus.sending,
      ReportErrorStatus.noMailApp,
    ]);
  });
}
