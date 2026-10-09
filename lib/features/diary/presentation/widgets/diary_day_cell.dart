import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_hero.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_day.dart';
import 'package:one_second_diary/shared/widgets/calendar/day_ring.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/media/clip_count_badge.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_surface.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// One day of the calendar, a pure widget: the grid passes the [day] and
/// its preformatted [number]. What it shows follows [DiaryDay.kind]:
/// - **recorded**: the first clip's picture with a white number (and a count
///   badge for several clips); an MU number while the picture loads or fails;
/// - **missed**: CARD and an MU number (FA text fails AA);
/// - **future**: FA at half alpha (no `Opacity` layer), not tappable, left
///   out of the semantics;
/// - **beforeFirstClip**: MU, tappable so it can import a clip;
/// - **unknown** (the diary is being read): not tappable;
/// - **filteredOut**: its picture under a surface scrim, not tappable.
///
/// [DiaryDay.isToday] and [DiaryDay.isSelected] each draw a [DayRing], today
/// winning. [alternativeColors] adds a blue check on recorded days and a
/// yellow outline on missed ones. The hit area reaches 3 px into the row
/// gaps. A long press on a recorded day opens the viewer ([onLongPress],
/// also the semantics action [longPressLabel]), the picture flying there
/// from the cell when [flies].
class DiaryDayCell extends StatelessWidget {
  const DiaryDayCell({
    super.key,
    required this.day,
    required this.number,
    required this.semanticsLabel,
    this.orientation = VideoOrientation.landscape,
    this.alternativeColors = false,
    this.onTap,
    this.onLongPress,
    this.longPressLabel,
    this.flies = false,
    this.cellHeight = height,
  });

  /// The cell's surface (its fill).
  static const Key surfaceKey = Key('diaryDayCell.surface');

  static const Key numberKey = Key('diaryDayCell.number');

  /// The blue check on a recorded day.
  static const Key checkKey = Key('diaryDayCell.check');

  /// The yellow outline on a missed day.
  static const Key outlineKey = Key('diaryDayCell.outline');

  /// The scrim over a filtered-out day's picture.
  static const Key scrimKey = Key('diaryDayCell.scrim');

  /// The cell height; taller in a tablet's two panes.
  static const double height = 42;

  /// The alternative colours' recorded-day blue: Material's `Colors.blue`,
  /// as the design has no blue token.
  static const Color alternativeBlue = Color(0xFF2196F3);

  static const double _outlineWidth = 1.5;
  static const double _checkSize = 14;
  static const double _futureAlpha = .5;

  /// How much of the surface covers a filtered-out day's picture.
  static const double _filteredOutScrim = .72;
  static const Duration _dissolve = Duration(milliseconds: 250);

  final DiaryDay day;

  /// The day of the month, formatted for the locale.
  final String number;

  /// The full date and the day's state, for screen readers.
  final String semanticsLabel;

  /// The profile's orientation: the picture follows the profile.
  final VideoOrientation orientation;

  /// A blue check on recorded days, a yellow outline on missed ones.
  final bool alternativeColors;

  /// Selects the day.
  final VoidCallback? onTap;

  /// Opens the viewer on a recorded day.
  final VoidCallback? onLongPress;

  /// What [onLongPress] does, for screen readers ("Full screen").
  final String? longPressLabel;

  /// The picture is the end of the viewer's flight.
  final bool flies;

  final double cellHeight;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final Color? ring = day.isToday
        ? colors.co
        : day.isSelected
        ? colors.tx
        : null;
    final Widget cell = SizedBox(
      height: cellHeight,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: <Widget>[
          DayRing(color: ring, gap: OsdSurface.of(context).color(colors)),
          AnimatedSwitcher(
            duration: OsdMotion.d(context, _dissolve),
            switchInCurve: OsdMotion.curve(context, OsdMotion.fastCurve),
            switchOutCurve: OsdMotion.curve(context, OsdMotion.fastCurve),
            child: _DayFace(
              key: ValueKey<bool>(day.clip != null),
              day: day,
              number: number,
              orientation: orientation,
              alternativeColors: alternativeColors,
              flies: flies,
            ),
          ),
        ],
      ),
    );
    if (day.kind == DiaryDayKind.future) return ExcludeSemantics(child: cell);
    final VoidCallback? onLongPress = day.kind == DiaryDayKind.recorded
        ? this.onLongPress
        : null;
    final String? longPressLabel = this.longPressLabel;
    return OsdHitSlop(
      slop: const EdgeInsets.symmetric(vertical: 3),
      child: OsdPressable(
        onTap: day.isSelectable ? onTap : null,
        onLongPress: onLongPress,
        customSemanticsActions: onLongPress == null || longPressLabel == null
            ? null
            : <CustomSemanticsAction, VoidCallback>{
                CustomSemanticsAction(label: longPressLabel): onLongPress,
              },
        haptic: OsdHaptic.selection,
        pressScale: OsdPressScale.icon.scale,
        overlay: OsdPressOverlay.none,
        borderRadius: BorderRadius.circular(OsdRadius.r10),
        minHitSize: 0,
        selected: day.isSelected,
        semanticsLabel: semanticsLabel,
        excludeChildSemantics: true,
        child: cell,
      ),
    );
  }
}

/// What a cell shows under its ring: the fill, the picture, the number and
/// the badges.
class _DayFace extends StatelessWidget {
  const _DayFace({
    super.key,
    required this.day,
    required this.number,
    required this.orientation,
    required this.alternativeColors,
    required this.flies,
  });

  final DiaryDay day;
  final String number;
  final VideoOrientation orientation;
  final bool alternativeColors;
  final bool flies;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r10);
    final bool recorded = day.kind == DiaryDayKind.recorded;
    final bool filteredOut = day.kind == DiaryDayKind.filteredOut;
    final bool pictured = recorded || filteredOut;
    final bool missed = day.kind == DiaryDayKind.missed;
    final bool outlined = missed && alternativeColors;
    final Color? fill = switch (day.kind) {
      DiaryDayKind.missed => colors.card,
      DiaryDayKind.unknown => colors.c2,
      _ => null,
    };
    final Color numberColor = switch (day.kind) {
      // Drawn with the picture (`_DayNumber` in the thumbnail's overlays).
      DiaryDayKind.recorded || DiaryDayKind.filteredOut => OsdMedia.onMedia,
      DiaryDayKind.missed ||
      DiaryDayKind.unknown ||
      DiaryDayKind.beforeFirstClip => colors.mu,
      DiaryDayKind.future => colors.fa.withValues(
        alpha: DiaryDayCell._futureAlpha,
      ),
    };
    return LightHairline(
      radius: radius,
      visible: missed && !outlined,
      child: DecoratedBox(
        key: DiaryDayCell.surfaceKey,
        decoration: BoxDecoration(color: fill, borderRadius: radius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (pictured)
              ClipHero(
                clip: day.clip!,
                radius: OsdRadius.r10,
                // In flight, the poster (the viewer's picture).
                slot: ClipThumbnailSlot.player,
                orientation: orientation,
                enabled: flies && recorded,
                child: ClipThumbnailView(
                  clip: day.clip!,
                  slot: ClipThumbnailSlot.calendarCell,
                  orientation: orientation,
                  radius: OsdRadius.r10,
                  // Once the picture is up, the white number and the badges
                  // (never over one that loads or can't be made); until
                  // then, and over a broken one, the number in MU without
                  // its shadow. A filtered-out day's picture stays faint
                  // under the surface, with an MU number.
                  overlay: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (filteredOut)
                        ColoredBox(
                          key: DiaryDayCell.scrimKey,
                          color: OsdSurface.of(context)
                              .color(colors)
                              .withValues(
                                alpha: DiaryDayCell._filteredOutScrim,
                              ),
                        ),
                      _DayNumber(
                        number: number,
                        color: filteredOut ? colors.mu : OsdMedia.onMedia,
                        shadow: recorded,
                      ),
                      if (recorded && (alternativeColors || day.clipCount > 1))
                        _PictureBadges(
                          clipCount: day.clipCount,
                          check: alternativeColors,
                        ),
                    ],
                  ),
                  placeholderOverlay: _DayNumber(
                    number: number,
                    color: colors.mu,
                    shadow: false,
                  ),
                ),
              ),
            if (outlined)
              DecoratedBox(
                key: DiaryDayCell.outlineKey,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: colors.yellow,
                    width: DiaryDayCell._outlineWidth,
                  ),
                ),
              ),
            // A pictured day's number is part of its picture (above).
            if (!pictured)
              _DayNumber(number: number, color: numberColor, shadow: false),
          ],
        ),
      ),
    );
  }
}

/// The day number, bottom-start, in [color], with the media shadow over a
/// picture ([shadow]).
class _DayNumber extends StatelessWidget {
  const _DayNumber({
    required this.number,
    required this.color,
    required this.shadow,
  });

  final String number;
  final Color color;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(5, 3, 5, 3),
    child: Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Text(
        number,
        key: DiaryDayCell.numberKey,
        maxLines: 1,
        softWrap: false,
        textScaler: OsdTextScale.scalerFor(context, OsdTextScaleRole.calendar),
        style: context.typography.dayNumber.copyWith(
          color: color,
          shadows: shadow ? const <Shadow>[OsdMedia.dayNumberShadow] : null,
        ),
      ),
    ),
  );
}

/// Over a recorded day's picture, once it is up: the alternative colours'
/// check at top-start and, for several clips, their count at top-end.
class _PictureBadges extends StatelessWidget {
  const _PictureBadges({required this.clipCount, required this.check});

  final int clipCount;
  final bool check;

  @override
  Widget build(BuildContext context) => Stack(
    children: <Widget>[
      if (check)
        const PositionedDirectional(
          top: 3,
          start: 3,
          child: _AlternativeCheck(),
        ),
      if (clipCount > 1)
        PositionedDirectional(
          top: 3,
          end: 3,
          child: ClipCountBadge(count: clipCount),
        ),
    ],
  );
}

/// The alternative colours' check on a recorded day.
class _AlternativeCheck extends StatelessWidget {
  const _AlternativeCheck();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    key: DiaryDayCell.checkKey,
    dimension: DiaryDayCell._checkSize,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: DiaryDayCell.alternativeBlue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: OsdIcon(OsdIcons.check, size: 11, color: OsdMedia.onMedia),
      ),
    ),
  );
}
