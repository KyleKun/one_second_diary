import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/contact_state.dart';

/// Contact: opens the user's mail app to the developer, through
/// `BugReportService`. Nothing is ever sent without the user. One request
/// at a time.
class ContactCubit extends Cubit<ContactState> {
  ContactCubit({required this._bugReports}) : super(const ContactState());

  final BugReportService _bugReports;

  /// "Something isn't working": the zipped logs, the English error-report
  /// subject and [body] (`errorMailBody` in the app language).
  Future<void> reportProblem({required String body}) =>
      _contact(ContactTopic.problem, () => _bugReports.reportError(body: body));

  /// "I have an idea": the Feedback subject, no attachment.
  Future<void> shareIdea() =>
      _contact(ContactTopic.idea, () => _bugReports.shareIdea(body: ''));

  Future<void> _contact(
    ContactTopic topic,
    Future<BugReportOutcome> Function() send,
  ) async {
    if (state.isBusy) return;
    emit(ContactState(status: ContactStatus.preparing, topic: topic));
    final BugReportOutcome outcome = await send();
    if (isClosed) return;
    emit(
      ContactState(
        status: outcome == BugReportOutcome.noMailApp
            ? ContactStatus.noMailApp
            : ContactStatus.mailOpened,
        topic: topic,
      ),
    );
  }
}
