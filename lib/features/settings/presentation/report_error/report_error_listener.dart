import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/no_mail_app_snackbar.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_cubit.dart';

/// Says so ([NoMailAppSnackbar]) each time the page's [ReportErrorCubit]
/// finds no mail app. Put it inside the page's `OsdSnackbarHost`.
class ReportErrorListener extends StatelessWidget {
  const ReportErrorListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocListener<ReportErrorCubit, ReportErrorStatus>(
        listenWhen: (ReportErrorStatus previous, ReportErrorStatus current) =>
            current == ReportErrorStatus.noMailApp,
        listener: (BuildContext context, ReportErrorStatus _) =>
            NoMailAppSnackbar.show(context),
        child: child,
      );
}
