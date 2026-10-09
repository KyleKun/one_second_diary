import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/domain/place_pick.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/place_chip.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The place sheet: the places [saved] and the clips' [recent] ones as
/// chips (a tap picks one and closes), then one line for a place typed
/// instead of the one found. Both rows narrow to what is typed.
///
/// Reset empties the field and stays (off while empty); Save, or the
/// keyboard's done, gives the place back trimmed (`''` clears it; a name
/// that is a saved place's is that place, coordinates included); "Save
/// this place", shown while the text is not saved yet, gives it back with
/// `PlacePick.save`; any other way out gives nothing back.
class PlaceSheet extends StatefulWidget {
  const PlaceSheet({
    super.key,
    required this.text,
    required this.saved,
    required this.recent,
  });

  static const Key resetKey = Key('placeSheet.reset');

  static const Key saveKey = Key('placeSheet.save');

  /// "Save this place".
  static const Key savePlaceKey = Key('placeSheet.savePlace');

  /// The chip of the saved place [name].
  static Key savedChipKey(String name) =>
      ValueKey<String>('placeSheet.saved.${SavedPlaceName.fold(name)}');

  /// The chip of the recent place [name].
  static Key recentChipKey(String name) =>
      ValueKey<String>('placeSheet.recent.${SavedPlaceName.fold(name)}');

  /// The longest place (the stamp is one line).
  static const int maxLength = SavedPlaceName.maxLength;

  /// The place it opens with.
  final String text;

  /// The saved places, most used first.
  final List<SavedPlace> saved;

  /// The clips' places not saved, most used first.
  final List<String> recent;

  /// Opens the sheet on [text]; completes with the pick, or null.
  static Future<PlacePick?> show(
    BuildContext context, {
    required String text,
    required List<SavedPlace> saved,
    required List<String> recent,
  }) => showOsdSheet<PlacePick>(
    context,
    title: Strings.saveVideoTabTwo,
    titleIcon: OsdIcons.editLocationAlt,
    titleIconColor: context.colors.purple,
    child: PlaceSheet(text: text, saved: saved, recent: recent),
  );

  @override
  State<PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<PlaceSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.text,
  )..addListener(_textChanged);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  // The chips narrow and "Save this place" follows what is typed.
  void _textChanged() => setState(() {});

  String get _typedKey => SavedPlaceName.fold(_text.text);

  bool _matches(String name) =>
      _typedKey.isEmpty || SavedPlaceName.fold(name).contains(_typedKey);

  /// The saved place the typed text names, or null.
  SavedPlace? get _savedMatch {
    final String key = _typedKey;
    if (key.isEmpty) return null;
    for (final SavedPlace place in widget.saved) {
      if (SavedPlaceName.fold(place.name) == key) return place;
    }
    return null;
  }

  void _reset() {
    unawaited(OsdHaptic.selection.play());
    _text.clear();
  }

  void _pop(PlacePick pick) => Navigator.of(context).pop(pick);

  void _save() => _pop(PlacePick(text: _text.text.trim(), saved: _savedMatch));

  void _savePlace() => _pop(PlacePick(text: _text.text.trim(), save: true));

  @override
  Widget build(BuildContext context) {
    final List<SavedPlace> saved = <SavedPlace>[
      for (final SavedPlace place in widget.saved)
        if (_matches(place.name)) place,
    ];
    final List<String> recent = <String>[
      for (final String place in widget.recent)
        if (_matches(place)) place,
    ];
    final bool canSavePlace =
        SavedPlaceName.validate(
          _text.text,
          existing: <String>[
            for (final SavedPlace place in widget.saved) place.name,
          ],
        ) ==
        null;
    final Widget reset = NeutralButton(
      key: PlaceSheet.resetKey,
      label: Strings.reset,
      onPressed: _text.text.isEmpty ? null : _reset,
    );
    final Widget save = PrimaryButton(
      key: PlaceSheet.saveKey,
      label: Strings.save,
      onPressed: _save,
    );
    final bool stacked =
        OsdTextScale.factorOf(context) > OsdTextScale.stackButtonRowsAbove;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s16,
      children: <Widget>[
        if (saved.isNotEmpty)
          _ChipGroup(
            label: Strings.savedPlaces,
            chips: <Widget>[
              for (final SavedPlace place in saved)
                PlaceChip(
                  key: PlaceSheet.savedChipKey(place.name),
                  label: place.name,
                  onTap: () => _pop(PlacePick(text: place.name, saved: place)),
                ),
            ],
          ),
        if (recent.isNotEmpty)
          _ChipGroup(
            label: Strings.recentPlaces,
            chips: <Widget>[
              for (final String place in recent)
                PlaceChip(
                  key: PlaceSheet.recentChipKey(place),
                  label: place,
                  onTap: () => _pop(PlacePick(text: place)),
                ),
            ],
          ),
        OsdTextField(
          controller: _text,
          autofocus: true,
          hint: Strings.enterLocation,
          semanticsLabel: Strings.saveVideoTabTwo,
          maxLength: PlaceSheet.maxLength,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        if (canSavePlace)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OsdTextButton(
              key: PlaceSheet.savePlaceKey,
              label: Strings.savePlace,
              icon: OsdIcons.place,
              tone: OsdTextButtonTone.secondary,
              hug: true,
              onPressed: _savePlace,
            ),
          ),
        if (stacked)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: OsdSpace.s12,
            children: <Widget>[save, reset],
          )
        else
          Row(
            spacing: OsdSpace.s12,
            children: <Widget>[
              Expanded(child: reset),
              Expanded(flex: 2, child: save),
            ],
          ),
      ],
    );
  }
}

/// A caption and a wrap of chips.
class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.label, required this.chips});

  final String label;

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: OsdSpace.s8,
    children: <Widget>[
      Text(
        label,
        style: context.typography.caption13.copyWith(color: context.colors.mu),
      ),
      Wrap(spacing: OsdSpace.s8, runSpacing: OsdSpace.s8, children: chips),
    ],
  );
}
