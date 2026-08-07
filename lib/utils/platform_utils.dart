import 'dart:io' as io;

/// Single place where the app branches on the host platform.
///
/// Everything that used to assume Android goes through here, so that finding
/// platform specific behaviour is a matter of looking for the callers of this
/// class instead of grepping for `dart:io` across the whole project.
class PlatformUtils {
  PlatformUtils._();

  static bool get isAndroid => io.Platform.isAndroid;

  static bool get isIOS => io.Platform.isIOS;
}
