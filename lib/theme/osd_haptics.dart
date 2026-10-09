import 'package:flutter/services.dart';

/// The four haptics of the design.
///
/// A haptic is never the only feedback: every moment also changes something
/// on screen.
enum OsdHaptic {
  /// Toggles, radios, tabs, chips, month/year/day picks, carousel index
  /// changes, slider steps, swatches, language pick, countdown ticks.
  selection,

  /// CTA taps (Save, Start my diary, Next), the Saved badge landing, Undo,
  /// movie done, photo set, links.
  light,

  /// Record start and auto-stop, long-press entering selection or edit,
  /// destructive confirm, profile create, version copied.
  medium,

  /// Once, when a text area hits its maximum length.
  heavy;

  Future<void> play() => switch (this) {
    OsdHaptic.selection => HapticFeedback.selectionClick(),
    OsdHaptic.light => HapticFeedback.lightImpact(),
    OsdHaptic.medium => HapticFeedback.mediumImpact(),
    OsdHaptic.heavy => HapticFeedback.heavyImpact(),
  };
}
