import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/language_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The Settings tab's "Language" row: the app language's own name, opening
/// the language sheet (which shows each language's flag; the row has none).
class LanguageSettingRow extends StatelessWidget {
  const LanguageSettingRow({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = context.select(
      (LocaleCubit cubit) => cubit.state.language,
    );
    return OsdListRow(
      title: Strings.language,
      icon: OsdIcons.translate,
      value: language.nativeName,
      trailing: const OsdRowTrailing.chevron(),
      onTap: () => LanguageSheet.show(context),
    );
  }
}
