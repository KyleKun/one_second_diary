import 'package:flutter/widgets.dart';

/// How the profile screens time what they say.
abstract final class ProfileFeedback {
  /// How long "Now recording into …" stays; null leaves it to the snackbar
  /// host's longer default while a screen reader runs.
  static Duration? recordingIntoDuration(BuildContext context) =>
      MediaQuery.accessibleNavigationOf(context)
      ? null
      : const Duration(milliseconds: 2500);
}
