import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/places_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/places_state.dart';
import 'package:one_second_diary/features/settings/presentation/pages/places_page.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/location_failure_dialogs.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The "Add place" / "Edit place" sheet of Settings › Places: the name
/// (Save adds or renames it; a refused name says why under the field) and,
/// for a saved place, its coordinates with "Use current location" (one
/// fix, the permission asked just in time) and "Remove coordinates", and
/// "Remove place" (asks first; the clips keep the place).
///
/// Open it with [show]. A fix that fails is said under the coordinates; a
/// permission blocked or the location service off opens the dialogs the
/// clip editor shows.
class EditPlaceSheet extends StatefulWidget {
  const EditPlaceSheet({super.key, this.place});

  static const Key bodyKey = Key('editPlaceSheet.body');

  static const Key fieldKey = Key('editPlaceSheet.field');

  static const Key saveKey = Key('editPlaceSheet.save');

  static const Key removeKey = Key('editPlaceSheet.remove');

  /// "Use current location".
  static const Key locateKey = Key('editPlaceSheet.locate');

  /// "Remove coordinates".
  static const Key clearCoordinatesKey = Key('editPlaceSheet.clearCoordinates');

  /// The coordinates line.
  static const Key coordinatesKey = Key('editPlaceSheet.coordinates');

  /// The place edited; null adds one.
  final SavedPlace? place;

  /// Opens the sheet on [place] (or empty, to add one) over the page of
  /// [cubit]. Completes when the sheet closes.
  static Future<void> show(
    BuildContext context, {
    required PlacesCubit cubit,
    SavedPlace? place,
  }) => showOsdSheet<void>(
    context,
    title: place == null ? Strings.addPlace : Strings.editPlace,
    titleIcon: OsdIcons.place,
    titleIconColor: context.colors.purple,
    child: BlocProvider<PlacesCubit>.value(
      value: cubit,
      child: EditPlaceSheet(key: bodyKey, place: place),
    ),
  );

  @override
  State<EditPlaceSheet> createState() => _EditPlaceSheetState();
}

class _EditPlaceSheetState extends State<EditPlaceSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.place?.name ?? '',
  )..addListener(_textChanged);
  SavedPlaceError? _error;

  /// Why the last "Use current location" found nothing, until the next.
  String? _locateError;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _editing => widget.place != null;

  /// Save follows what is typed; a refused name is forgiven on the next
  /// keystroke.
  void _textChanged() {
    if (mounted) setState(() => _error = null);
  }

  /// Whether what is typed names the place differently (or, adding, at
  /// all).
  bool get _changed {
    final String cleaned = SavedPlaceName.clean(_text.text);
    final SavedPlace? place = widget.place;
    return place == null ? cleaned.isNotEmpty : cleaned != place.name;
  }

  Future<void> _save() async {
    final PlacesCubit cubit = context.read<PlacesCubit>();
    final SavedPlace? place = widget.place;
    final String raw = _text.text;
    final SavedPlaceError? error = place == null
        ? await cubit.add(raw)
        : await cubit.rename(place.name, raw);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    unawaited(OsdHaptic.light.play());
    Navigator.of(context).pop();
  }

  void _locate() {
    setState(() => _locateError = null);
    unawaited(
      context.read<PlacesCubit>().useCurrentLocation(
        widget.place!.name,
        languageCode: Localizations.localeOf(context).languageCode,
      ),
    );
  }

  void _clearCoordinates() {
    unawaited(OsdHaptic.selection.play());
    unawaited(context.read<PlacesCubit>().clearCoordinates(widget.place!.name));
  }

  Future<void> _remove() async {
    final PlacesCubit cubit = context.read<PlacesCubit>();
    final CommonLabels labels = CommonLabels.of(context);
    final String name = widget.place!.name;
    final bool confirmed = await OsdConfirmDialog.show(
      context,
      title: Strings.removePlaceTitle(place: name),
      body: Strings.removePlaceBody,
      cancelLabel: labels.cancel,
      confirmLabel: labels.delete,
      destructive: true,
      badgeIcon: OsdIcons.delete,
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).pop();
    unawaited(cubit.remove(name));
  }

  String _errorText(SavedPlaceError error) => switch (error) {
    SavedPlaceError.empty => Strings.placeErrorEmpty,
    SavedPlaceError.tooLong => Strings.placeErrorTooLong(
      max: SavedPlaceName.maxLength,
    ),
    SavedPlaceError.duplicate => Strings.placeErrorDuplicate,
  };

  Future<void> _explain(LocationFailure failure) async {
    final String? line = await explainLocationFailure(context, failure);
    if (mounted && line != null) setState(() => _locateError = line);
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final SavedPlace? original = widget.place;
    // The coordinates follow a fix found while the sheet is open.
    final SavedPlace? place = original == null
        ? null
        : context.select(
            (PlacesCubit cubit) => cubit.state.placeNamed(original.name),
          );
    final bool locating = context.select(
      (PlacesCubit cubit) => cubit.state.isLocating,
    );
    final String? locateError = _locateError;
    return BlocListener<PlacesCubit, PlacesState>(
      listenWhen: (PlacesState previous, PlacesState current) =>
          previous.locateFailures < current.locateFailures,
      listener: (BuildContext context, PlacesState state) =>
          unawaited(_explain(state.lastLocateFailure!)),
      child: Column(
        key: EditPlaceSheet.bodyKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: OsdSpace.sheetGap,
        children: <Widget>[
          OsdTextField(
            key: EditPlaceSheet.fieldKey,
            controller: _text,
            hint: Strings.placeName,
            leadingIcon: OsdIcons.driveFileRenameOutline,
            autofocus: !_editing,
            maxLength: SavedPlaceName.maxLength,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            errorText: _error == null ? null : _errorText(_error!),
            onSubmitted: (_) => unawaited(_save()),
          ),
          if (place != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: OsdSpace.s8,
              children: <Widget>[
                Row(
                  spacing: OsdSpace.s8,
                  children: <Widget>[
                    OsdIcon(OsdIcons.place, size: 18, color: colors.purple),
                    Expanded(
                      child: Text(
                        PlacesPage.coordinatesOf(place) ??
                            Strings.placeNoCoordinates,
                        key: EditPlaceSheet.coordinatesKey,
                        style: typography.body14.copyWith(color: colors.sub),
                      ),
                    ),
                  ],
                ),
                if (locateError != null)
                  Text(
                    locateError,
                    style: typography.caption13.copyWith(color: colors.red),
                  ),
                OsdTextButton(
                  key: EditPlaceSheet.locateKey,
                  label: locating
                      ? Strings.saveVideoLocationFinding
                      : Strings.placeUseCurrentLocation,
                  icon: OsdIcons.myLocation,
                  tone: OsdTextButtonTone.secondary,
                  onPressed: locating ? null : _locate,
                ),
                if (place.hasCoordinates)
                  OsdTextButton(
                    key: EditPlaceSheet.clearCoordinatesKey,
                    label: Strings.placeRemoveCoordinates,
                    icon: OsdIcons.close,
                    tone: OsdTextButtonTone.muted,
                    onPressed: _clearCoordinates,
                  ),
              ],
            ),
          PrimaryButton(
            key: EditPlaceSheet.saveKey,
            label: Strings.save,
            onPressed: _changed ? () => unawaited(_save()) : null,
          ),
          if (_editing)
            OsdTextButton(
              key: EditPlaceSheet.removeKey,
              label: Strings.removePlace,
              icon: OsdIcons.delete,
              tone: OsdTextButtonTone.destructive,
              onPressed: () => unawaited(_remove()),
            ),
        ],
      ),
    );
  }
}
