import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/presentation/places_formats.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_actions.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_meta_chip.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_poster.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_section_title.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_sheet_title.dart';
import 'package:one_second_diary/shared/widgets/buttons/circle_icon_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/media/clip_date_label.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// One place in the sheet: its span, clips and distance from home, Play
/// all and Make movie, the pin when the place has none or a changeable
/// one, and its clips newest first.
class PlaceDetail extends StatelessWidget {
  const PlaceDetail({
    super.key,
    required this.place,
    required this.kmFromHome,
    required this.onClose,
    required this.onPlay,
    required this.onMakeMovie,
    this.onPin,
  });

  final DiaryPlace place;

  /// Null when the place or home is not on the map.
  final double? kmFromHome;
  final VoidCallback onClose;

  /// [index] into [DiaryPlace.clips].
  final void Function(int index, {required bool autoplay}) onPlay;
  final VoidCallback? onMakeMovie;

  /// Opens the pin sheet; null when the clips' own fixes place it.
  final VoidCallback? onPin;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final PlacesFormats formats = PlacesFormats.of(context);
    final int n = place.clips.length;
    final double? km = kmFromHome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: <Widget>[
        PlacesSheetTitle(
          title: place.name,
          subtitle: place.country ?? formats.clips(n),
          trailing: CircleIconButton(
            icon: OsdIcons.close,
            tooltip: CommonLabels.of(context).close,
            onPressed: onClose,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            PlaceMetaChip(
              icon: OsdIcons.calendarMonth,
              label: formats.range(place.first, place.last),
            ),
            PlaceMetaChip(icon: OsdIcons.videoLibrary, label: formats.clips(n)),
            PlaceMetaChip(
              icon: OsdIcons.myLocation,
              label: place.home
                  ? Strings.placesHome
                  : km != null
                  ? Strings.placesKmFromHome(km: formats.km(km))
                  : Strings.placesNotOnMap,
            ),
          ],
        ),
        PlaceActions(
          onPlayAll: () => onPlay(0, autoplay: true),
          onMakeMovie: onMakeMovie,
        ),
        if (onPin != null)
          OsdTextButton(
            label: place.isMapped
                ? Strings.placesChangePin
                : Strings.placesPinOnMap,
            icon: OsdIcons.editLocationAlt,
            tone: OsdTextButtonTone.secondary,
            onPressed: onPin,
          ),
        PlacesSectionTitle(Strings.placesClips),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = (constraints.maxWidth - 2 * _gap) / 3;
            return RepaintBoundary(
              child: Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: <Widget>[
                  for (int i = n - 1; i >= 0; i--)
                    SizedBox(
                      width: width,
                      child: _ClipTile(
                        clip: place.clips[i],
                        label: formats.shortDay(place.clips[i].day),
                        semanticsLabel: formats.day(place.clips[i].day),
                        onTap: () => onPlay(i, autoplay: false),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.clip,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final ClipRef clip;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r12);
    return OsdPressable(
      onTap: onTap,
      borderRadius: radius,
      semanticsLabel: semanticsLabel,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: radius,
          child: PlacePoster(
            clip: clip,
            tagBadge: true,
            overlay: DecoratedBox(
              decoration: const BoxDecoration(gradient: OsdMedia.clipScrim),
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: ClipDateLabel(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
