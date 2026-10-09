import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/contact_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/contact_state.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_state.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_state.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_state.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/no_mail_app_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

/// What the Settings tab says when something fails, in a snackbar of the
/// nearest host (the shell's, above the nav):
/// - a theme, language or name the phone refuses to store: "Couldn't save
///   this setting" (each refusal, since every attempt starts from an
///   in-progress status);
/// - Contact with no mail app on the phone: "No email app found",
///   "Write to {address}" with "Copy address".
class SettingsFeedbackListener extends StatelessWidget {
  const SettingsFeedbackListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: <BlocListener<dynamic, dynamic>>[
      BlocListener<ThemeCubit, ThemeState>(
        listenWhen: (ThemeState previous, ThemeState current) =>
            previous.status != current.status &&
            current.status == ThemeStatus.saveFailed,
        listener: _saveFailed,
      ),
      BlocListener<LocaleCubit, LocaleState>(
        listenWhen: (LocaleState previous, LocaleState current) =>
            previous.status != current.status &&
            current.status == LocaleStatus.saveFailed,
        listener: _saveFailed,
      ),
      BlocListener<UserNameCubit, UserNameState>(
        listenWhen: (UserNameState previous, UserNameState current) =>
            previous.status != current.status &&
            current.status == UserNameStatus.saveFailed,
        listener: _saveFailed,
      ),
      BlocListener<ContactCubit, ContactState>(
        listenWhen: (ContactState previous, ContactState current) =>
            previous.status != current.status &&
            current.status == ContactStatus.noMailApp,
        listener: (BuildContext context, ContactState _) =>
            NoMailAppSnackbar.show(context),
      ),
    ],
    child: child,
  );

  static void _saveFailed(BuildContext context, Object? _) => OsdSnackbar.show(
    context,
    kind: OsdSnackKind.error,
    title: Strings.preferencesSaveFailed,
  );
}
