import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';

/// Clamps the system text scale for a subtree to [role]'s maximum.
///
/// Wrap the app with [OsdTextScaleRole.root], a nav bar with
/// [OsdTextScaleRole.navLabel], and so on. [OsdTextScaleRole.unscaled] turns
/// text scaling off (stamps, video subtitles, artwork).
class OsdTextScaleClamp extends StatelessWidget {
  const OsdTextScaleClamp({super.key, required this.role, required this.child});

  final OsdTextScaleRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (role == OsdTextScaleRole.unscaled) {
      return MediaQuery.withNoTextScaling(child: child);
    }
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: role.maxScaleFactor,
      child: child,
    );
  }
}
