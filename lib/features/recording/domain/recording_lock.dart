import 'package:flutter/services.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// How the camera starts for a profile: turning with the phone, or locked
/// to a shape. Stored per profile; absent means [of] the profile's own
/// shape.
enum RecordingLock {
  auto,
  landscape,
  portrait;

  /// The stored value, or null when none or unknown.
  static RecordingLock? parse(String stored) => values.asNameMap()[stored];

  static RecordingLock of(VideoOrientation orientation) =>
      switch (orientation) {
        VideoOrientation.landscape => landscape,
        VideoOrientation.portrait => portrait,
      };

  /// The lock that keeps [orientation]'s shape.
  static RecordingLock ofHeld(DeviceOrientation orientation) =>
      isLandscape(orientation) ? landscape : portrait;

  static bool isLandscape(DeviceOrientation orientation) =>
      switch (orientation) {
        DeviceOrientation.landscapeLeft ||
        DeviceOrientation.landscapeRight => true,
        DeviceOrientation.portraitUp || DeviceOrientation.portraitDown => false,
      };

  /// The way a recording is kept under this lock: [held] when it has the
  /// locked shape (so the clip is never upside down), else the shape's
  /// upright way; null while [auto].
  DeviceOrientation? applyTo(DeviceOrientation held) => switch (this) {
    auto => null,
    landscape => isLandscape(held) ? held : DeviceOrientation.landscapeLeft,
    portrait => isLandscape(held) ? DeviceOrientation.portraitUp : held,
  };
}
