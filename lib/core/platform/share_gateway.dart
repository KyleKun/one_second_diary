import 'dart:ui';

/// The system share sheet (`share_plus`).
///
/// [origin] is the global rectangle of the tapped control. iPad needs it to
/// anchor the popover (it crashes without one); other devices ignore it.
///
/// Fire-and-forget: neither call ever throws. A sheet the platform cannot
/// open is logged by the implementation; what the user then does in the
/// sheet (share, cancel) is not reported.
abstract interface class ShareGateway {
  /// Shares the local files at [paths] (clips, movies).
  Future<void> shareFiles(List<String> paths, {Rect? origin});

  /// Shares plain [text] (the "share the app" message).
  Future<void> shareText(String text, {Rect? origin});
}
