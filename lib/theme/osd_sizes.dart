import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Hit targets, fixed chrome and layout limits.
abstract final class OsdSizes {
  /// Minimum hit target (Android guideline). Visuals may be smaller: grow the
  /// hit area with transparent padding and keep the visual in place.
  static const double minTap = 48;

  /// The iOS hit-target floor, tested separately.
  static const double minTapIOS = 44;

  static const double iconDefault = 22;

  /// Every icon size the design uses.
  static const List<double> iconSizes = <double>[
    12,
    15,
    16,
    17,
    18,
    20,
    22,
    24,
    26,
    30,
    32,
    34,
    36,
    38,
    40,
    44,
    60,
  ];

  /// Every avatar diameter the design uses.
  static const List<double> avatarDiameters = <double>[28, 30, 36, 40, 44, 96];

  /// Every button height the design uses.
  static const List<double> buttonHeights = <double>[
    40,
    44,
    46,
    48,
    50,
    52,
    54,
    56,
    58,
  ];

  static const double appBarHeight = 52;
  static const double viewerTopBarHeight = 56;

  /// Bottom nav content, above its bottom padding ([navHeight]).
  static const double navContentHeight = 82;

  /// The nav's minimum bottom padding, which the system inset replaces.
  static const double navMinBottomPadding = 6;

  /// OsdSwitch track.
  static const Size switchSize = Size(44, 26);

  static const Size sheetHandleSize = Size(40, 4);

  /// OsdListRow without a subtitle.
  static const double listRowHeight = 54;
  static const double radioRowHeight = 50;
  static const double navRowHeight = 52;
  static const double languageRowHeight = 50;

  /// Content max width on tablets, centred with BG either side.
  static const double contentMaxWidth = 560;

  /// Devices whose shortest side reaches this are tablets.
  static const double tabletShortestSide = 600;

  /// Widest a dialog gets ([dialogWidth]).
  static const double dialogMaxWidth = 322;

  /// Widest a bottom sheet gets.
  static const double sheetMaxWidth = 560;

  /// Widest the snackbar gets.
  static const double snackbarMaxWidth = 480;

  /// Widest feed and viewer media get.
  static const double mediaMaxWidth = 900;

  /// The bottom nav's height: 82 plus `max(6, bottomInset)`. The 6 px is a
  /// minimum, not stacked on the inset.
  static double navHeight({required double bottomInset}) =>
      navContentHeight + math.max(navMinBottomPadding, bottomInset);

  /// Dialog width on a screen [screenWidth] wide: `min(322, screenWidth − 32)`.
  static double dialogWidth(double screenWidth) =>
      math.min(dialogMaxWidth, screenWidth - 32);
}
