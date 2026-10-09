import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The app's launcher art in a plain rounded rect, with no shadow.
///
/// Decoded at size × DPR. Decorative unless [semanticLabel] is given.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    required this.radius,
    this.semanticLabel,
  });

  /// The notification preview.
  const AppLogo.preview({super.key, this.semanticLabel})
    : size = 36,
      radius = OsdRadius.r9;

  /// The licence page.
  const AppLogo.licenses({super.key, this.semanticLabel})
    : size = 64,
      radius = OsdRadius.r16;

  /// The About hero.
  const AppLogo.about({super.key, this.semanticLabel})
    : size = 108,
      radius = OsdRadius.r26;

  static const String asset = 'assets/images/app_logo.png';

  final double size;

  final double radius;

  /// A semantics label, when the logo is not decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      ),
    ),
  );
}
