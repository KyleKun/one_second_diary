import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The Settings tab's "About" row: the installed version. The value is
/// empty until the version has been read (no spinner).
class AboutRow extends StatelessWidget {
  const AboutRow({super.key});

  @override
  Widget build(BuildContext context) {
    final String? version = context.select(
      (SettingsCubit cubit) => cubit.state.version,
    );
    return OsdListRow(
      title: Strings.about,
      icon: OsdIcons.info,
      value: version,
      trailing: const OsdRowTrailing.chevron(),
      onTap: () => AppRoute.about.push<void>(context),
    );
  }
}
