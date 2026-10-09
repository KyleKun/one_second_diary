import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';

/// The Settings tab's "Profiles" row: the active profile's name (Default's
/// is translated), opening the profiles page.
class ActiveProfileRow extends StatelessWidget {
  const ActiveProfileRow({super.key});

  @override
  Widget build(BuildContext context) {
    final String name = context.select(
      (ProfilesCubit cubit) => cubit.state.active.displayName,
    );
    return OsdListRow(
      title: Strings.profiles,
      icon: OsdIcons.person,
      value: name,
      valueMaxLines: OsdTextScale.nameLines(context),
      trailing: const OsdRowTrailing.chevron(),
      onTap: () => AppRoute.profiles.push<void>(context),
    );
  }
}
