import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/features/journey/data/place_lookup.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_row.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/location_failure_dialogs.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// How the pin sheet closed.
enum PinPlaceSheetResult {
  /// The place has its spot.
  pinned,

  /// The user wants to turn the globe to the spot; the page takes over.
  pickOnGlobe,
}

/// "Where is this?" for a typed place: pin it where the phone is, copy
/// another place's spot, search a name and confirm the match, or hand
/// over to the globe.
class PinPlaceSheet extends StatefulWidget {
  const PinPlaceSheet({super.key, required this.place, required this.mapped});

  static const Key bodyKey = Key('pinPlaceSheet.body');
  static const Key currentKey = Key('pinPlaceSheet.current');
  static const Key sameAsKey = Key('pinPlaceSheet.sameAs');
  static const Key searchKey = Key('pinPlaceSheet.search');
  static const Key globeKey = Key('pinPlaceSheet.globe');
  static const Key searchFieldKey = Key('pinPlaceSheet.searchField');
  static const Key useThisKey = Key('pinPlaceSheet.useThis');

  final DiaryPlace place;

  /// Other places already on the map, most clips first.
  final List<DiaryPlace> mapped;

  /// Opens the sheet for [place] over the page of [cubit]; completes with
  /// how it closed, or null when dismissed.
  static Future<PinPlaceSheetResult?> show(
    BuildContext context, {
    required PlacesMapCubit cubit,
    required DiaryPlace place,
    required List<DiaryPlace> mapped,
  }) => showOsdSheet<PinPlaceSheetResult>(
    context,
    title: place.fullName,
    subtitle: Strings.placesPinWhere,
    titleIcon: OsdIcons.place,
    titleIconColor: context.colors.green,
    child: BlocProvider<PlacesMapCubit>.value(
      value: cubit,
      child: PinPlaceSheet(key: bodyKey, place: place, mapped: mapped),
    ),
  );

  @override
  State<PinPlaceSheet> createState() => _PinPlaceSheetState();
}

enum _Mode { menu, sameAs, search }

class _PinPlaceSheetState extends State<PinPlaceSheet> {
  _Mode _mode = _Mode.menu;
  late final TextEditingController _query = TextEditingController(
    text: widget.place.fullName,
  );
  String? _locateError;
  bool _searching = false;
  PlaceLookupResult? _result;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String get _languageCode => Localizations.localeOf(context).languageCode;

  void _close(PinPlaceSheetResult result) {
    if (result == PinPlaceSheetResult.pinned) {
      unawaited(OsdHaptic.light.play());
    }
    Navigator.of(context).pop(result);
  }

  Future<void> _useCurrent() async {
    setState(() => _locateError = null);
    final LocationFailure? failure = await context
        .read<PlacesMapCubit>()
        .pinCurrentLocation(widget.place.fullName, languageCode: _languageCode);
    if (!mounted) return;
    if (failure == null) return _close(PinPlaceSheetResult.pinned);
    final String? line = await explainLocationFailure(context, failure);
    if (mounted && line != null) setState(() => _locateError = line);
  }

  Future<void> _pinAt(GeoPoint at) async {
    final bool stored = await context.read<PlacesMapCubit>().pin(
      widget.place.fullName,
      at,
    );
    if (!mounted) return;
    if (stored) {
      _close(PinPlaceSheetResult.pinned);
    } else {
      setState(() => _locateError = Strings.placeLocationUnavailable);
    }
  }

  Future<void> _search() async {
    final String query = _query.text.trim();
    if (query.isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _result = null;
    });
    final PlaceLookupResult result = await context
        .read<PlacesMapCubit>()
        .search(query, languageCode: _languageCode);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool pinning = context.select(
      (PlacesMapCubit cubit) => cubit.state.pinning != null,
    );
    return Column(
      key: PinPlaceSheet.bodyKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.sheetGap,
      children: switch (_mode) {
        _Mode.menu => _menu(context, pinning: pinning),
        _Mode.sameAs => _sameAs(context),
        _Mode.search => _searchMode(context),
      },
    );
  }

  List<Widget> _menu(BuildContext context, {required bool pinning}) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final String? locateError = _locateError;
    return <Widget>[
      OsdListRow(
        key: PinPlaceSheet.currentKey,
        title: pinning
            ? Strings.saveVideoLocationFinding
            : Strings.placeUseCurrentLocation,
        subtitle: Strings.placesPinCurrentHint,
        icon: OsdIcons.myLocation,
        iconColor: colors.green,
        trailing: const OsdRowTrailing.chevron(),
        enabled: !pinning,
        onTap: pinning ? null : () => unawaited(_useCurrent()),
      ),
      if (locateError != null)
        Text(
          locateError,
          style: typography.caption13.copyWith(color: colors.red),
        ),
      if (widget.mapped.isNotEmpty)
        OsdListRow(
          key: PinPlaceSheet.sameAsKey,
          title: Strings.placesPinSameAs,
          subtitle: Strings.placesPinSameAsHint,
          icon: OsdIcons.place,
          iconColor: colors.purple,
          trailing: const OsdRowTrailing.chevron(),
          onTap: () => setState(() => _mode = _Mode.sameAs),
        ),
      OsdListRow(
        key: PinPlaceSheet.searchKey,
        title: Strings.placesPinSearch,
        subtitle: Strings.placesPinSearchHint,
        icon: OsdIcons.search,
        iconColor: colors.co,
        trailing: const OsdRowTrailing.chevron(),
        onTap: () => setState(() => _mode = _Mode.search),
      ),
      OsdListRow(
        key: PinPlaceSheet.globeKey,
        title: Strings.placesPinOnGlobe,
        subtitle: Strings.placesPinOnGlobeHint,
        icon: OsdIcons.language,
        iconColor: colors.green,
        trailing: const OsdRowTrailing.chevron(),
        onTap: () => _close(PinPlaceSheetResult.pickOnGlobe),
      ),
    ];
  }

  Widget _back() => OsdTextButton(
    label: CommonLabels.of(context).back,
    icon: OsdIcons.arrowBack,
    tone: OsdTextButtonTone.muted,
    onPressed: () => setState(() => _mode = _Mode.menu),
  );

  List<Widget> _sameAs(BuildContext context) => <Widget>[
    _back(),
    for (final DiaryPlace other in widget.mapped)
      PlaceRow(place: other, onTap: () => unawaited(_pinAt(other.at!))),
  ];

  List<Widget> _searchMode(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return <Widget>[
      _back(),
      OsdTextField(
        key: PinPlaceSheet.searchFieldKey,
        controller: _query,
        hint: Strings.placesPinSearchField,
        leadingIcon: OsdIcons.search,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => unawaited(_search()),
      ),
      Text(
        Strings.placesPinPrivacy,
        style: typography.caption13.copyWith(color: colors.mu),
      ),
      switch (_result) {
        PlaceFound(:final GeoPoint at, :final String? name) => OsdCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(OsdSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: OsdSpace.s12,
            children: <Widget>[
              Text(
                name == null
                    ? Strings.placesPinFoundUnnamed
                    : Strings.placesJoin(a: Strings.placesPinFound, b: name),
                style: typography.rowTitleStrong.copyWith(color: colors.tx),
              ),
              PrimaryButton(
                key: PinPlaceSheet.useThisKey,
                label: Strings.placesPinUseThis,
                icon: OsdIcons.check,
                onPressed: () => unawaited(_pinAt(at)),
              ),
            ],
          ),
        ),
        PlaceUnknown() => Text(
          Strings.placesPinNotFound,
          style: typography.caption13.copyWith(color: colors.red),
        ),
        PlaceLookupFailed() => Text(
          Strings.placesPinOffline,
          style: typography.caption13.copyWith(color: colors.red),
        ),
        null => PrimaryButton(
          label: Strings.placesPinSearchAction,
          loadingLabel: Strings.placesPinSearching,
          icon: OsdIcons.search,
          loading: _searching,
          onPressed: () => unawaited(_search()),
        ),
      },
      if (_result != null && !_searching)
        OsdTextButton(
          label: Strings.placesPinSearchAction,
          icon: OsdIcons.replay,
          tone: OsdTextButtonTone.secondary,
          onPressed: () => unawaited(_search()),
        ),
    ];
  }
}
