import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/onboarding/presentation/onboarding_motion.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/identity/app_logo.dart';
import 'package:one_second_diary/theme/osd_artwork.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_shadows.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The third intro slide's artwork: the app logo with the promise slapped
/// on it as four paper stickers, "No ads", "No account", "Works offline",
/// "Stays on your phone".
///
/// Entrance: the logo comes in, then the stickers stick one by one,
/// turning from straight to their angle. A screen reader reads the promise
/// once, the stickers as sentences in order ("No ads. No account. Works
/// offline. Stays on your phone."); the logo is decorative.
class PrivacyArtwork extends StatelessWidget {
  const PrivacyArtwork({
    super.key,
    required this.entrance,
    required this.textDirection,
  });

  /// How long the logo and the four stickers take to come in.
  static const Duration entranceLength = Duration(milliseconds: 750);

  /// 0 → 1 over [entranceLength].
  final Animation<double> entrance;

  /// The reading direction around the artwork: each sticker's icon sits at
  /// its start, while the stickers stay where they are drawn.
  final TextDirection textDirection;

  // (left, top, turn in degrees, icon); paint order.
  static const List<(double, double, double, IconData)> _stickers =
      <(double, double, double, IconData)>[
        (26, 56, -6, OsdIcons.block),
        (186, 92, 5, OsdIcons.personOff),
        (24, 236, 3, OsdIcons.wifiOff),
        (96, 306, -4, OsdIcons.lock),
      ];

  @override
  Widget build(BuildContext context) {
    final List<String> labels = <String>[
      Strings.onboardingChipNoAds,
      Strings.onboardingChipNoAccount,
      Strings.onboardingChipOffline,
      Strings.onboardingChipOnDevice,
    ];
    final List<Widget> stickers = <Widget>[
      for (final (int i, (double left, _, _, IconData icon))
          in _stickers.indexed)
        Directionality(
          textDirection: textDirection,
          // A long label stops 8 short of the card's edge.
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 350 - left - 8),
            child: _Sticker(icon: icon, label: labels[i]),
          ),
        ),
    ];
    const Widget logo = _LogoTile();
    final Widget artwork = AnimatedBuilder(
      animation: entrance,
      builder: (BuildContext context, _) {
        final double t = entrance.value;
        final double logoIn = OnboardingMotion.span(
          Duration.zero,
          OnboardingMotion.logoIn,
          entranceLength,
          curve: Curves.easeOutCubic,
        ).transform(t);
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: 119,
              top: 129,
              width: _LogoTile.side,
              height: _LogoTile.side,
              child: Opacity(
                opacity: logoIn,
                child: Transform.scale(
                  scale:
                      OnboardingMotion.logoScale +
                      (1 - OnboardingMotion.logoScale) * logoIn,
                  child: logo,
                ),
              ),
            ),
            for (final (int i, (double left, double top, double turn, _))
                in _stickers.indexed)
              Positioned(
                left: left,
                top: top,
                child: _stuck(t, i, turn, stickers[i]),
              ),
          ],
        );
      },
    );
    return Semantics(
      container: true,
      label: _sentences(context, labels),
      child: ExcludeSemantics(child: artwork),
    );
  }

  /// [parts] as sentences, each ended and spaced the way the app language
  /// ends a sentence: "No ads. No account." or "无广告。无需账号。".
  static String _sentences(BuildContext context, List<String> parts) {
    final String language = Localizations.localeOf(context).languageCode;
    final (String stop, String gap) = language == 'zh' ? ('。', '') : ('.', ' ');
    return parts.map((String part) => '$part$stop').join(gap);
  }

  /// Sticker [i] at [turn]°, as far as its sticking has come at [t].
  static Widget _stuck(double t, int i, double turn, Widget sticker) {
    final Interval span = OnboardingMotion.span(
      OnboardingMotion.chipDelay + OnboardingMotion.chipStagger * i,
      OnboardingMotion.chipIn,
      entranceLength,
    );
    final double stick = Curves.easeOutBack.transform(span.transform(t));
    final double shown = span.transform(t);
    return Opacity(
      opacity: shown,
      child: Transform.rotate(
        angle: turn * stick * math.pi / 180,
        child: Transform.scale(
          scale:
              OnboardingMotion.chipScale +
              (1 - OnboardingMotion.chipScale) * stick,
          child: sticker,
        ),
      ),
    );
  }
}

/// The launcher art with its shadow.
class _LogoTile extends StatelessWidget {
  const _LogoTile();

  static const double side = 112;

  static const BoxShadow _shadow = BoxShadow(
    color: Color(0x40000000),
    offset: Offset(0, 16),
    blurRadius: OsdShadows.filmBandBlur,
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(OsdRadius.r28),
      boxShadow: const <BoxShadow>[_shadow],
    ),
    child: const AppLogo(size: side, radius: OsdRadius.r28),
  );
}

/// A paper sticker: a green-ink glyph and the label, which shrinks rather
/// than wraps when a language runs long.
class _Sticker extends StatelessWidget {
  const _Sticker({required this.icon, required this.label});

  final IconData icon;
  final String label;

  static const BoxShadow _shadow = BoxShadow(
    color: Color(0x2E000000),
    offset: Offset(0, 10),
    blurRadius: OsdShadows.stickerChipBlur,
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(
      color: OsdArtwork.paper,
      shape: StadiumBorder(),
      shadows: <BoxShadow>[_shadow],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: <Widget>[
          OsdIcon(icon, size: 20, color: OsdArtwork.greenInk),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: context.typography.titleSmall.copyWith(
                  color: OsdArtwork.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
