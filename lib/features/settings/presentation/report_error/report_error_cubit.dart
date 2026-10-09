import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';

/// Where a failure surface's "Report error" is.
enum ReportErrorStatus {
  /// Not tapped.
  idle,

  /// The logs are being zipped and the mail app opened.
  sending,

  /// The mail app opened (with the logs, or a plain `mailto:` link).
  opened,

  /// Nothing on the phone could open an email.
  noMailApp,
}

/// "Report error" on a failure surface: after a movie failed, when the
/// camera can't start or record. The user's mail app opens to the developer
/// with the zipped logs; nothing is sent without the user. Contact has its
/// own `ContactCubit` for its two topics; all of them say "No email app
/// found" the same way (`NoMailAppSnackbar`, through `ReportErrorListener`
/// here).
///
/// Each report passes through [ReportErrorStatus.sending], so the page's
/// "no mail app" message shows on every tap that finds none.
class ReportErrorCubit extends Cubit<ReportErrorStatus> {
  ReportErrorCubit({required this._reports}) : super(ReportErrorStatus.idle);

  final BugReportService _reports;

  /// Opens the mail app with [body], the localised `errorMailBody` the page
  /// reads. A tap while one is being sent does nothing.
  Future<void> report({required String body}) async {
    if (state == ReportErrorStatus.sending) return;
    emit(ReportErrorStatus.sending);
    final BugReportOutcome outcome = await _reports.reportError(body: body);
    if (isClosed) return;
    emit(
      outcome == BugReportOutcome.noMailApp
          ? ReportErrorStatus.noMailApp
          : ReportErrorStatus.opened,
    );
  }
}
