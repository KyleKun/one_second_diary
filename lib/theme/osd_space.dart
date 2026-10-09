import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Spacing tokens, in logical px from the 390 × 844 frames.
///
/// The design only uses the steps below; any other number in a row spec is a
/// sum of them (58 = 8 + 44 + 6).
abstract final class OsdSpace {
  static const double s2 = 2;
  static const double s3 = 3;
  static const double s4 = 4;
  static const double s5 = 5;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s24 = 24;
  static const double s26 = 26;
  static const double s28 = 28;
  static const double s32 = 32;

  /// Cards, lists, grids and players to the screen edge.
  static const double pageGutter = 16;

  /// Screen titles, month headers and section labels to the screen edge.
  static const double textInset = 20;

  /// Onboarding title and body blocks.
  static const double onboardingTextInset = 28;
  static const double heroTextInset = 30;

  /// Between cards in a list.
  static const double cardGap = 12;
  static const double cardGapCompact = 10;

  /// OsdListRow horizontal padding.
  static const double rowPadH = 16;

  /// OsdListRow vertical padding when the row has a subtitle.
  static const double rowPadV = 13;

  /// OsdListRow gap between leading icon, text and trailing.
  static const double rowGap = 14;

  /// Button icon → label.
  static const double iconLabelGap = 8;

  /// Chip and stat-label icon → label.
  static const double chipIconGap = 6;

  /// Nav icon → label.
  static const double navIconLabelGap = 4;

  /// Between sheet children.
  static const double sheetGap = 16;

  /// Between dialog children.
  static const double dialogGap = 12;

  /// OsdDialog padding.
  static const EdgeInsets dialogPadding = EdgeInsets.fromLTRB(22, 26, 22, 18);

  /// Calendar grid gap.
  static const double gridGapCalendar = 10;

  /// Swatch, month-tile and 4-clip mosaic gap.
  static const double gridGapSwatches = 8;

  /// Clip picker, carousel and bento gap.
  static const double gridGapClips = 10;

  /// Movie grid horizontal gap.
  static const double gridGapMoviesH = 12;

  /// Movie grid vertical gap.
  static const double gridGapMoviesV = 16;

  /// Snackbar gap above the bottom nav (bottom 92 on the reference frame).
  static const double snackbarAboveNav = 14;

  /// Snackbar gap above a bottom CTA or panel.
  static const double snackbarAboveCta = 12;

  /// Snackbar gap above Today's Edit / Add another row.
  static const double snackbarAboveTodayActions = 4;

  /// Snackbar gap to the bottom edge with no anchor, plus the inset.
  static const double snackbarNoAnchor = 16;

  /// Space under a pinned CTA or sheet: the mock value [base] (24, 28 or 34),
  /// or 12 above the home indicator when that is taller.
  static double bottomGap(BuildContext context, double base) =>
      math.max(base, MediaQuery.viewPaddingOf(context).bottom + 12);

  /// OsdSheet padding: 20/12/20 with [bottomGap] 28 under the content, or 16
  /// above the keyboard while it is up.
  static EdgeInsets sheetPadding(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return EdgeInsets.fromLTRB(
      20,
      12,
      20,
      keyboard > 0 ? 16 + keyboard : bottomGap(context, 28),
    );
  }
}
