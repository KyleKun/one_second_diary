import 'package:flutter/material.dart';

class Constants {
  // Added in video metadata so we can differentiate from previous versions
  static const String artist = 'One Second Diary (v1.5)';
  static const String donationUrl = 'https://www.buymeacoffee.com/kylekun';
  static const String backupTutorialUrl = 'https://youtu.be/1Kf3ysnNNNE';
  static const String email = 'mailto:kylekundev@gmail.com';
  static const String githubUrl = 'https://github.com/KyleKun/one_second_diary';

  /// Caps how tall a preview `AspectRatio` box (save-video, save-photo,
  /// calendar-editor, subtitle-editor) is allowed to grow relative to the
  /// screen height. Sized to full available width with no ceiling, a
  /// portrait (9:16) preview wants roughly 1.78x the screen width in
  /// height — comfortably taller than the screen — and pushes whatever
  /// else is on the page off-screen. A landscape (16:9) preview never
  /// comes close to this fraction at any reasonable screen width, so
  /// capping it has no visible effect there.
  static const double previewMaxHeightFraction = 0.4;
}

class AppColors {
  static const Color mainColor = Color(0xffff6366);
  static const Color dark = Color(0xff212121);
  static const Color light = Color(0xffEEEEEE);
  static const Color purple = Color(0xff7D7ABC);
  static const Color green = Color(0xff7AC74F);
  static const Color yellow = Color(0xffE5B25D);
  static const Color rose = Color(0xffFFEBE7);
  static const Color orange = Color(0xffFFA500);
}
