import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/theme/osd_theme.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Forces the dark palette on a subtree: the camera, the viewer and the
/// full-screen movie player stay dark in both themes.
///
/// It keeps the ambient `OsdTypography`, so locale-dependent fonts carry over,
/// and asks for light status icons over a black navigation bar. Sheets and
/// dialogs opened from inside inherit it when pushed with
/// `useRootNavigator: false`; otherwise wrap them again.
class OsdForcedDark extends StatelessWidget {
  const OsdForcedDark({super.key, required this.child});

  final Widget child;

  static const SystemUiOverlayStyle _systemBars = SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Color(0x00000000),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemBars,
      child: Theme(
        data: OsdTheme.dark(typography: OsdTypography.of(context)),
        child: child,
      ),
    );
  }
}
