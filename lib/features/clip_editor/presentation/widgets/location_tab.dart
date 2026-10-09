import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/domain/geotag.dart';
import 'package:one_second_diary/features/clip_editor/domain/place_pick.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clip_editor/presentation/sheets/place_sheet.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/card_crossfade.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button_frame.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_info_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The Location tab: "Show my location" and its switch, a place typed
/// instead, and the line saying the place name is looked up through the
/// phone's location service.
///
/// When no place comes back, the typed card pulses once (over [pulse]) to
/// offer itself.
class LocationTab extends StatelessWidget {
  const LocationTab({super.key});

  static const Key geotagKey = Key('locationTab.geotag');

  static const Key typedKey = Key('locationTab.typed');

  static const Key clearKey = Key('locationTab.clear');

  static const Key pulseKey = Key('locationTab.pulse');

  static const Duration pulse = Duration(milliseconds: 600);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 10,
    children: <Widget>[
      const _GeotagCard(key: geotagKey),
      const _TypedPlaceCard(key: typedKey),
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
        child: Text(
          Strings.saveVideoLocationDisclosure,
          style: context.typography.caption13.copyWith(
            color: context.colors.mu,
          ),
        ),
      ),
    ],
  );
}

/// "Show my location": the switch and what it found, read as one toggle
/// button.
class _GeotagCard extends StatelessWidget {
  const _GeotagCard({super.key});

  void _toggle(BuildContext context) {
    final EditClipCubit editor = context.read<EditClipCubit>();
    unawaited(
      editor.geotagSwitched(
        on: !editor.state.geotag.isOn,
        languageCode: Localizations.localeOf(context).languageCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Geotag geotag = context.select(
      (EditClipCubit editor) => editor.state.geotag,
    );
    final String? place = geotag.place;
    final (String value, bool muted) = switch (geotag.status) {
      GeotagStatus.off when geotag.typed.isNotEmpty && place != null => (
        place,
        true,
      ),
      GeotagStatus.off => (Strings.saveVideoLocationOffValue, true),
      GeotagStatus.finding => (Strings.saveVideoLocationFinding, true),
      GeotagStatus.found => (place ?? '', false),
      GeotagStatus.unavailable => (Strings.saveVideoLocationUnavailable, true),
      GeotagStatus.denied ||
      GeotagStatus.blocked => (Strings.saveVideoLocationAllow, false),
      GeotagStatus.serviceOff => (Strings.locationOffDialogTitle, false),
    };
    // One node for a screen reader: the card's "label, value" with the
    // switch's on/off (both toggle it).
    return MergeSemantics(
      child: OsdInfoCard(
        leading: OsdIcon(
          OsdIcons.myLocation,
          size: 22,
          color: context.colors.purple,
        ),
        label: Strings.enableGeotagging,
        value: value,
        valueMuted: muted,
        loading: geotag.status == GeotagStatus.finding,
        trailing: OsdSwitch(
          value: geotag.isOn,
          onChanged: (_) => _toggle(context),
        ),
        onTap: () => _toggle(context),
      ),
    );
  }
}

/// A place typed or picked instead of the one found.
class _TypedPlaceCard extends StatefulWidget {
  const _TypedPlaceCard({super.key});

  @override
  State<_TypedPlaceCard> createState() => _TypedPlaceCardState();
}

class _TypedPlaceCardState extends State<_TypedPlaceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: LocationTab.pulse,
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Opens the place sheet on [typed] and applies its pick: a saved place
  /// with its coordinates, or the text; "Save this place" also saves it.
  Future<void> _edit(String typed) async {
    final EditClipCubit editor = context.read<EditClipCubit>();
    final PlacePick? pick = await PlaceSheet.show(
      context,
      text: typed,
      saved: editor.savedPlaces(),
      recent: editor.recentPlaces(),
    );
    if (pick == null || editor.isClosed) return;
    final SavedPlace? saved = pick.saved;
    if (saved != null) {
      editor.pickPlace(saved);
    } else {
      editor.typedPlaceChanged(pick.text);
    }
    if (pick.save) unawaited(editor.savePlace());
  }

  void _offer() {
    _pulse.duration = OsdMotion.d(context, LocationTab.pulse);
    unawaited(_pulse.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final String typed = context.select(
      (EditClipCubit editor) => editor.state.geotag.typed,
    );
    final OsdColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r18);
    return BlocListener<EditClipCubit, EditClipState>(
      listenWhen: (EditClipState previous, EditClipState current) =>
          previous.geotag.status != GeotagStatus.unavailable &&
          current.geotag.status == GeotagStatus.unavailable,
      listener: (BuildContext context, _) => _offer(),
      child: Stack(
        children: <Widget>[
          CardCrossfade(
            id: typed,
            child: OsdInfoCard(
              leading: OsdIcon(
                OsdIcons.editLocationAlt,
                size: 22,
                color: colors.purple,
              ),
              label: typed.isEmpty
                  ? Strings.optionalLabel
                  : Strings.saveVideoTypedLocationLabel,
              value: typed.isEmpty ? Strings.saveVideoTypeLocation : typed,
              trailing: typed.isEmpty
                  ? OsdIcon(OsdIcons.chevronRight, size: 22, color: colors.fa)
                  : OsdIconButtonFrame(
                      key: LocationTab.clearKey,
                      icon: OsdIcons.close,
                      tooltip: Strings.reset,
                      visualSize: 36,
                      glyphSize: 20,
                      glyphColor: colors.fa,
                      onPressed: () =>
                          context.read<EditClipCubit>().typedPlaceChanged(''),
                    ),
              onTap: () => unawaited(_edit(typed)),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (BuildContext context, Widget? child) => Opacity(
                  key: LocationTab.pulseKey,
                  // 0 → 1 → 0.
                  opacity: 1 - (2 * _pulse.value - 1).abs(),
                  child: child,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.sel,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
