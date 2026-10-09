import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The camera's fixed geometry: a portrait layout whatever the phone does,
/// the preview edge to edge above a black panel.
abstract final class CameraLayout {
  /// The panel's content: 18 above the 32 clip-length chip, 20 below it,
  /// then the 88 shutter row.
  static const double panelContent = 158;

  /// The panel's room below the shutter row, which takes the home
  /// indicator or the gesture bar.
  static const double panelBottomMin = 42;

  /// Above the system's bottom inset.
  static const double panelBottomOverInset = 8;

  /// From the panel's top to the clip-length chip, and from the chip to the
  /// shutter row.
  static const double panelTopPadding = 18;
  static const double chipToShutterRow = 20;

  /// The clip-length chip's height, and the shutter's box.
  static const double chipHeight = 32;
  static const double shutterSize = 88;

  /// The shutter row's side padding, and its widest (tablets keep tune and
  /// switch near the shutter).
  static const double shutterRowPadding = 44;
  static const double shutterRowMaxWidth = 390;

  /// The top bar sits this far under the status bar; the timer pill a
  /// little lower.
  static const double topBarBelowInset = 12;
  static const double timerPillBelowInset = 16;

  /// The side margins of the top bar.
  static const double topBarSide = 16;

  /// From the top bar to the hint pill under it ("Microphone off").
  static const double topBarToHint = 10;

  /// Between the orientation chip and the bubble under it.
  static const double chipToBubble = 10;

  /// The close button's and the orientation chip's height.
  static const double topControl = 44;

  /// The smallest gap between the close button and the orientation chip.
  static const double closeToChip = 12;

  /// The height of the black panel under the preview: 200 on any phone
  /// whose bottom inset is 34 or less.
  static double panelHeightOf(BuildContext context) =>
      panelContent +
      math.max(
        panelBottomMin,
        MediaQuery.viewPaddingOf(context).bottom + panelBottomOverInset,
      );

  /// The top of the shutter row within the panel.
  static const double shutterRowTop =
      panelTopPadding + chipHeight + chipToShutterRow;
}
