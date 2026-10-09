// Contact. "Something isn't working" mails the zipped logs to the
// developer; "I have an idea" opens a mail with the Feedback subject.
// Nothing is sent without the user.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/contact_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/contact_state.dart';

import '../../../../shared/fakes/fake_app_info_gateway.dart';
import '../../../../support/support.dart';
import '../../../../support/track_1d/fake_archive_gateway.dart';

void main() {
  late FakeEmailGateway email;
  late AppPaths paths;

  Future<ContactCubit> cubit() async {
    paths = await createTestPaths();
    email = FakeEmailGateway();
    final ContactCubit cubit = ContactCubit(
      bugReports: BugReportService(
        logger: memoryLogger(MemoryLogSink()),
        paths: paths,
        archive: FakeArchiveGateway(),
        email: email,
        logsUnavailable: () => '(logs unavailable)',
        appInfo: FakeAppInfoGateway(appVersion: '2.0.0'),
      ),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('"Something isn\'t working" prepares the logs, then opens the mail '
      'with them attached; "I have an idea" opens a mail with the Feedback '
      'subject and no attachment', () async {
    final ContactCubit contact = await cubit();
    final List<ContactState> states = <ContactState>[];
    contact.stream.listen(states.add);

    await contact.reportProblem(body: 'What happened?');
    await pumpEventQueue();

    expect(
      states.first,
      const ContactState(
        status: ContactStatus.preparing,
        topic: ContactTopic.problem,
      ),
    );
    expect(contact.state.status, ContactStatus.mailOpened);
    expect(email.sent.single.recipient, BugReportService.developerEmail);
    expect(
      email.sent.single.subject,
      '[One Second Diary - v2.0.0] App Error Report',
    );
    expect(email.sent.single.body, 'What happened?');
    expect(email.sent.single.attachmentPaths, <String>[paths.logsZipPath]);

    await contact.shareIdea();

    expect(contact.state.status, ContactStatus.mailOpened);
    expect(
      email.mailtos.single.subject,
      '[One Second Diary - v2.0.0] Feedback',
    );
    expect(email.sent, hasLength(1));
  });

  test('a phone with no mail app says so, each time; a second tap while the '
      'first is on its way does nothing', () async {
    final ContactCubit contact = await cubit();

    await Future.wait(<Future<void>>[
      contact.reportProblem(body: ''),
      contact.shareIdea(),
    ]);

    expect(email.sent, hasLength(1));
    expect(email.mailtos, isEmpty);

    email
      ..sendError = StateError('No mail account')
      ..mailtoResult = false;
    final List<ContactStatus> statuses = <ContactStatus>[];
    contact.stream.listen((ContactState s) => statuses.add(s.status));

    await contact.reportProblem(body: '');
    await contact.shareIdea();
    await pumpEventQueue();

    expect(statuses, <ContactStatus>[
      ContactStatus.preparing,
      ContactStatus.noMailApp,
      ContactStatus.preparing,
      ContactStatus.noMailApp,
    ]);
  });
}
