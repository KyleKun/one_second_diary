import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/places_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/places_state.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/edit_place_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/shared/widgets/surfaces/empty_state.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// Settings › Places: every saved place, most used first, with how often
/// it was picked and its coordinates (or that it has none). A tap opens
/// [EditPlaceSheet] (rename, use the current location, remove the
/// coordinates, remove); "Add place" at the bottom opens it empty.
class PlacesPage extends StatelessWidget {
  const PlacesPage({super.key});

  static const Key listKey = Key('placesPage.list');

  static const Key emptyKey = Key('placesPage.empty');

  /// "Add place".
  static const Key addKey = Key('placesPage.add');

  /// The row of one place.
  static Key rowKey(String name) =>
      ValueKey<String>('placesPage.row.${SavedPlaceName.fold(name)}');

  /// "48.8566, 2.3522": a saved place's coordinates, or null without.
  static String? coordinatesOf(SavedPlace place) {
    final double? latitude = place.latitude;
    final double? longitude = place.longitude;
    if (latitude == null || longitude == null) return null;
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: OsdAppBar(title: Strings.places),
      body: OsdSnackbarHost(
        child: _PlacesFeedback(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: OsdSizes.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Expanded(child: _PlaceList()),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      OsdSpace.pageGutter,
                      12,
                      OsdSpace.pageGutter,
                      math.max(28, bottomInset + 12),
                    ),
                    child: const _AddButton(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The list of places, or the empty state once the store has been read.
class _PlaceList extends StatelessWidget {
  const _PlaceList();

  @override
  Widget build(BuildContext context) {
    final (List<SavedPlace> places, bool loaded) = context.select(
      (PlacesCubit cubit) => (cubit.state.places, cubit.state.loaded),
    );
    if (!loaded) return const SizedBox.shrink();
    if (places.isEmpty) {
      return Padding(
        key: PlacesPage.emptyKey,
        padding: const EdgeInsets.symmetric(horizontal: OsdSpace.textInset),
        child: EmptyState(
          icon: OsdIcons.place,
          title: Strings.placesNoneYet,
          body: Strings.managePlacesDescription,
        ),
      );
    }
    return ListView(
      key: PlacesPage.listKey,
      padding: const EdgeInsets.fromLTRB(0, OsdSpace.s4, 0, OsdSpace.s24),
      children: <Widget>[
        OsdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < places.length; i++) ...<Widget>[
                if (i > 0) const OsdDivider(),
                _PlaceRow(place: places[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One place: its name, its coordinates (or "No coordinates") and how
/// often it was picked.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place});

  final SavedPlace place;

  @override
  Widget build(BuildContext context) => OsdListRow(
    key: PlacesPage.rowKey(place.name),
    title: place.name,
    subtitle: PlacesPage.coordinatesOf(place) ?? Strings.placeNoCoordinates,
    value: Strings.placeUses(
      place.uses,
      format: LocaleFormats.of(context).numbers,
    ),
    icon: OsdIcons.place,
    iconColor: context.colors.purple,
    trailing: const OsdRowTrailing.chevron(),
    onTap: () => unawaited(
      EditPlaceSheet.show(
        context,
        cubit: context.read<PlacesCubit>(),
        place: place,
      ),
    ),
  );
}

/// "Add place". It opens the sheet from under the page's snackbar host.
class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) => SnackbarAnchor(
    gap: OsdSpace.snackbarAboveCta,
    child: PrimaryButton(
      key: PlacesPage.addKey,
      label: Strings.addPlace,
      icon: OsdIcons.add,
      size: OsdButtonSize.medium,
      onPressed: () => unawaited(
        EditPlaceSheet.show(context, cubit: context.read<PlacesCubit>()),
      ),
    ),
  );
}

/// "Couldn't save this setting" when a change could not be stored.
class _PlacesFeedback extends StatelessWidget {
  const _PlacesFeedback({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocListener<PlacesCubit, PlacesState>(
    listenWhen: (PlacesState previous, PlacesState current) =>
        previous.saveFailures < current.saveFailures,
    listener: (BuildContext context, _) => OsdSnackbar.show(
      context,
      kind: OsdSnackKind.error,
      title: Strings.preferencesSaveFailed,
    ),
    child: child,
  );
}
