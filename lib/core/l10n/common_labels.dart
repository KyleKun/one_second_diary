import 'package:flutter/material.dart';

/// Generic labels Flutter already translates into every app language, read
/// from `MaterialLocalizations`: back, close, delete, cancel, continue,
/// select all, the month arrows and "Today".
///
/// An OSD key for these would show English in the other 11 languages, next
/// to Material's own translated "Cancel" in the time picker. This is the one
/// context-taking exception to "text only through `Strings`"; every other
/// label is a `Strings` member.
final class CommonLabels {
  const CommonLabels._(this._material);

  /// The labels in the language of [context]'s `Localizations`.
  factory CommonLabels.of(BuildContext context) =>
      CommonLabels._(MaterialLocalizations.of(context));

  final MaterialLocalizations _material;

  String get back => _material.backButtonTooltip;

  String get close => _material.closeButtonLabel;

  String get delete => _material.deleteButtonTooltip;

  String get cancel => _material.cancelButtonLabel;

  String get continueAction => _material.continueButtonLabel;

  String get selectAll => _material.selectAllButtonLabel;

  String get previousMonth => _material.previousMonthTooltip;

  String get nextMonth => _material.nextMonthTooltip;

  String get today => _material.currentDateLabel;
}
