import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/your_name_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The Settings tab's "Your name" row: the name greetings use, or "Not
/// set", opening the name sheet.
class YourNameRow extends StatelessWidget {
  const YourNameRow({super.key});

  @override
  Widget build(BuildContext context) {
    final String name = context.select(
      (UserNameCubit cubit) => cubit.state.name,
    );
    return OsdListRow(
      title: Strings.yourName,
      icon: OsdIcons.badge,
      value: name.isEmpty ? Strings.yourNameNotSet : name,
      trailing: const OsdRowTrailing.chevron(),
      onTap: () => YourNameSheet.show(context),
    );
  }
}
