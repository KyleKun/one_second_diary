import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/display_text.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/onboarding/presentation/onboarding_motion.dart';
import 'package:one_second_diary/theme/osd_artwork.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_shadows.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The first intro slide's artwork: three polaroids pinned on the card,
/// dated 12 days back, 6 days back and "Today", the front one last.
///
/// Drawn in the card's artwork box. It enters as the photos are pinned one
/// by one: each drops, settles and turns back into place. Decorative: the
/// title says it.
class MemoriesArtwork extends StatefulWidget {
  const MemoriesArtwork({
    super.key,
    required this.entrance,
    required this.today,
  });

  static const Key photoBoxKey = Key('memoriesArtwork.photo');

  /// How long the three polaroids take to land.
  static const Duration entranceLength = Duration(milliseconds: 700);

  /// The photos; a box stays plain while its photo is missing.
  static const String pagodaAsset = 'assets/images/clip_pagoda.png';
  static const String templeAsset = 'assets/images/clip_temple.png';

  /// 0 → 1 over [entranceLength].
  final Animation<double> entrance;

  /// The front polaroid's day.
  final LocalDay today;

  @override
  State<MemoriesArtwork> createState() => _MemoriesArtworkState();
}

class _MemoriesArtworkState extends State<MemoriesArtwork> {
  // (left, top, turn in degrees, photo, crop, days back); paint order.
  static const List<(double, double, double, String, Alignment, int)> _pins =
      <(double, double, double, String, Alignment, int)>[
        (22, 48, -9, MemoriesArtwork.pagodaAsset, Alignment(-.4, 0), 12),
        (176, 30, 7, MemoriesArtwork.templeAsset, Alignment(.4, 0), 6),
        (96, 176, -2, MemoriesArtwork.templeAsset, Alignment(-.6, 0), 0),
      ];

  List<String> _labels = const <String>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Formatted once per language, never in build.
    final DateFormat format = LocaleFormats.of(context).date('MMMd');
    final String today = CommonLabels.of(context).today;
    _labels = <String>[
      for (final (_, _, _, _, _, int back) in _pins)
        if (back == 0)
          today
        else
          DisplayText.safe(
            format.format(widget.today.addDays(-back).toLocalDateTime()),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> polaroids = <Widget>[
      for (final (int i, (_, _, _, String photo, Alignment crop, _))
          in _pins.indexed)
        _Polaroid(photo: photo, crop: crop, label: _labels[i]),
    ];
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: widget.entrance,
        builder: (BuildContext context, _) => Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            for (final (int i, (double left, double top, double turn, _, _, _))
                in _pins.indexed)
              Positioned(
                left: left,
                top: top,
                width: _Polaroid.size.width,
                height: _Polaroid.size.height,
                child: _landing(i, turn, polaroids[i]),
              ),
          ],
        ),
      ),
    );
  }

  /// Polaroid [i], turned [turn]°, as far as its landing has come.
  Widget _landing(int i, double turn, Widget polaroid) {
    final Interval span = OnboardingMotion.span(
      OnboardingMotion.polaroidStagger * i,
      OnboardingMotion.polaroidIn,
      MemoriesArtwork.entranceLength,
    );
    final double t = span.transform(widget.entrance.value);
    final double settle = Curves.easeOutBack.transform(t);
    final double shown = Curves.easeOut.transform(t);
    return Opacity(
      opacity: shown,
      child: Transform.translate(
        offset: Offset(0, -OnboardingMotion.polaroidDrop * (1 - settle)),
        child: Transform.rotate(
          angle:
              (turn + OnboardingMotion.polaroidTurn * (1 - settle)) *
              math.pi /
              180,
          child: Transform.scale(
            scale: 1 + (OnboardingMotion.polaroidScale - 1) * (1 - settle),
            child: polaroid,
          ),
        ),
      ),
    );
  }
}

/// One polaroid: paper with a soft shadow, the photo cropped into its box,
/// and the day handwritten under it.
class _Polaroid extends StatelessWidget {
  const _Polaroid({
    required this.photo,
    required this.crop,
    required this.label,
  });

  /// The outer size: the photo and the padding around it.
  static const Size size = Size(186, 138);

  static const Size _photo = Size(170, 104);

  static const BoxShadow _shadow = BoxShadow(
    color: Color(0x47000000),
    offset: Offset(0, 14),
    blurRadius: OsdShadows.polaroidBlur,
  );

  final String photo;
  final Alignment crop;
  final String label;

  @override
  Widget build(BuildContext context) {
    final int cacheWidth =
        (_photo.width * MediaQuery.devicePixelRatioOf(context)).round();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: OsdArtwork.paper,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const <BoxShadow>[_shadow],
      ),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 26),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(OsdRadius.r2),
              child: ColoredBox(
                key: MemoriesArtwork.photoBoxKey,
                color: context.colors.c2,
                child: SizedBox.fromSize(
                  size: _photo,
                  child: Image.asset(
                    photo,
                    fit: BoxFit.cover,
                    alignment: crop,
                    cacheWidth: cacheWidth,
                    excludeFromSemantics: true,
                    errorBuilder: (BuildContext context, Object error, _) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 6,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: context.typography
                    .stampPolaroid(label)
                    .copyWith(color: OsdArtwork.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
