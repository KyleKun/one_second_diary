import 'package:flutter/painting.dart';

/// Accent tints.
///
/// A tint is one RGB at a fixed alpha, the same in both themes. Paint it
/// translucent over the current surface; never pre-blend it. The red tints use
/// the dark RED RGB in both themes.
abstract final class OsdTints {
  /// CO @ .06: RecordButton outer halo.
  static const Color coTint06 = Color(0x0FEF5558);

  /// CO @ .12: onboarding illustration card, selected clip tile overlay.
  static const Color coTint12 = Color(0x1FEF5558);

  /// CO @ .14: MakeMovieChip fill, RecordButton inner halo.
  static const Color coTint14 = Color(0x24EF5558);

  /// #FF7C7F @ .12: destructive square buttons, viewer delete tile, dialog
  /// icon badge, blocked banner.
  static const Color redTint12 = Color(0x1FFF7C7F);

  /// #FF7C7F @ .16: bug icon tile.
  static const Color redTint16 = Color(0x29FF7C7F);

  /// #FF7C7F @ .20: snackbar error and delete badges.
  static const Color redTint20 = Color(0x33FF7C7F);

  /// GREEN @ .14: onboarding illustration card.
  static const Color greenTint14 = Color(0x247AC74F);

  /// GREEN @ .20: snackbar success badge.
  static const Color greenTint20 = Color(0x337AC74F);

  /// PURPLE @ .16: onboarding illustration card.
  static const Color purpleTint16 = Color(0x297D7ABC);

  /// YELLOW @ .12: OsdTipCard, WarningPill.
  static const Color yellowTint12 = Color(0x1FE5B25D);

  /// YELLOW @ .14: WaveBadge.
  static const Color yellowTint14 = Color(0x24E5B25D);

  /// YELLOW @ .16: idea icon tile.
  static const Color yellowTint16 = Color(0x29E5B25D);

  /// Black @ .08: pressed overlay on CO and RED fills.
  static const Color pressOnFill = Color(0x14000000);
}
