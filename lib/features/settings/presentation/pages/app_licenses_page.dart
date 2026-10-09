import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/domain/app_identity.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/about_cubit.dart';
import 'package:one_second_diary/shared/widgets/identity/app_logo.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

/// Licenses: Flutter's licence page, as `showLicensePage` builds it, as a
/// route of its own: the app's name, its version and copyright over the
/// logo, then every package's licences and the bundled fonts' (registered
/// at launch).
///
/// The app theme already styles its app bar, lists and text; its cards take
/// CARD, and its back arrows (this page's and the package pages') are the
/// OSD glyph through the theme's `actionIconTheme`, as on every `OsdAppBar`,
/// not Flutter's stock one.
class AppLicensesPage extends StatelessWidget {
  const AppLicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final (String? version, int year) = context.select(
      (AboutCubit cubit) => (cubit.state.versionLabel, cubit.state.year),
    );
    final ThemeData theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(cardColor: context.colors.card),
      child: LicensePage(
        applicationName: AppIdentity.name,
        applicationVersion: version == null
            ? null
            : Strings.appVersion(version: version),
        applicationIcon: const AppLogo.licenses(),
        applicationLegalese: Strings.aboutCopyright(
          author: AppIdentity.author,
          year: year,
        ),
      ),
    );
  }
}
