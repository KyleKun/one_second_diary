import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/places_cubit.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The Settings tab's "Places" row: how many places are saved ("No places
/// yet" before the first), opening Settings › Places.
class PlacesSettingRow extends StatelessWidget {
  const PlacesSettingRow({super.key});

  @override
  Widget build(BuildContext context) {
    final (int count, bool loaded) = context.select(
      (PlacesCubit cubit) => (cubit.state.places.length, cubit.state.loaded),
    );
    return OsdListRow(
      title: Strings.places,
      icon: OsdIcons.place,
      value: !loaded
          ? null
          : count == 0
          ? Strings.placesNoneYet
          : Strings.placeCount(
              count,
              format: LocaleFormats.of(context).numbers,
            ),
      trailing: const OsdRowTrailing.chevron(),
      onTap: () => AppRoute.places.push<void>(context),
    );
  }
}
