import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_cubit.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The Settings tab's "Tags" row: how many tags the libraries hold ("No
/// tags yet" before the first), opening Settings › Tags.
class TagsSettingRow extends StatelessWidget {
  const TagsSettingRow({super.key});

  @override
  Widget build(BuildContext context) {
    final (int count, bool loaded) = context.select(
      (TagsCubit cubit) => (cubit.state.tags.length, cubit.state.loaded),
    );
    return OsdListRow(
      title: Strings.tags,
      icon: OsdIcons.sell,
      value: !loaded
          ? null
          : count == 0
          ? Strings.tagsNoneYet
          : Strings.tagCount(count, format: LocaleFormats.of(context).numbers),
      trailing: const OsdRowTrailing.chevron(),
      onTap: () => AppRoute.tags.push<void>(context),
    );
  }
}
