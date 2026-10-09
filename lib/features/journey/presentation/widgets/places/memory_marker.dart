import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/presentation/place_cluster.dart';
import 'package:one_second_diary/features/journey/presentation/places_formats.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_poster.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_colors.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A memory on the globe: the newest clip's poster on a pin, a stack of
/// cards when places merge, the clip count, and the name when zoomed in or
/// highlighted. Pops in after [delay].
class MemoryMarker extends StatefulWidget {
  const MemoryMarker({
    super.key,
    required this.cluster,
    required this.highlighted,
    required this.dimmed,
    required this.showLabel,
    required this.delay,
    required this.onTap,
  });

  /// The marker's box and where its ground dot sits in it.
  static const double width = 128;
  static const double height = 96;
  static const double anchorY = 92;
  static const double bubble = 48;

  final PlaceCluster cluster;
  final bool highlighted;
  final bool dimmed;
  final bool showLabel;
  final Duration delay;
  final VoidCallback onTap;

  @override
  State<MemoryMarker> createState() => _MemoryMarkerState();
}

class _MemoryMarkerState extends State<MemoryMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _pop,
    curve: Curves.easeOutBack,
  );
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pop.isAnimating || _pop.value > 0 || _timer != null) return;
    if (OsdMotion.reduced(context)) {
      _pop.value = 1;
    } else {
      _timer = Timer(widget.delay, () => unawaited(_pop.forward()));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final PlacesFormats formats = PlacesFormats.of(context);
    final PlaceCluster c = widget.cluster;
    final Duration quick = OsdMotion.d(context, OsdMotion.standard);
    final String name = c.single
        ? c.lead.name
        : Strings.placesStackLabel(
            name: c.lead.name,
            count: formats.number(c.members.length - 1),
          );
    final String clips = formats.clips(c.clips);
    return AnimatedOpacity(
      opacity: widget.dimmed ? .4 : 1,
      duration: quick,
      child: ScaleTransition(
        scale: _scale,
        alignment: const Alignment(
          0,
          MemoryMarker.anchorY / MemoryMarker.height * 2 - 1,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            ExcludeSemantics(
              child: AnimatedOpacity(
                opacity: widget.showLabel ? 1 : 0,
                duration: quick,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: PlacesColors.labelFill,
                    borderRadius: BorderRadius.circular(OsdRadius.full),
                    border: Border.all(color: PlacesColors.glassBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.badge12.copyWith(color: colors.tx),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedScale(
              scale: widget.highlighted ? 1.14 : 1,
              alignment: Alignment.bottomCenter,
              duration: quick,
              curve: OsdMotion.curve(context, Curves.easeOutBack),
              child: OsdPressable(
                onTap: widget.onTap,
                pressScale: OsdPressScale.icon.scale,
                borderRadius: BorderRadius.circular(OsdRadius.r14),
                haptic: null,
                semanticsLabel: c.single
                    ? Strings.placesMarkerSemantics(
                        name: c.lead.name,
                        clips: clips,
                      )
                    : Strings.placesStackSemantics(
                        c.members.length - 1,
                        name: c.lead.name,
                        clips: clips,
                        format: formats.numbers,
                      ),
                child: _Bubble(
                  cluster: c,
                  highlighted: widget.highlighted,
                  count: formats.number(c.clips),
                ),
              ),
            ),
            CustomPaint(
              size: const Size(12, 6),
              painter: _TailPainter(
                widget.highlighted ? colors.co : OsdMedia.onMedia,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.highlighted ? colors.co : OsdMedia.onMedia,
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: PlacesColors.dotShadow, blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.cluster,
    required this.highlighted,
    required this.count,
  });

  final PlaceCluster cluster;
  final bool highlighted;
  final String count;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final Color border = highlighted ? colors.co : OsdMedia.onMedia;
    Widget card(DiaryPlace place, {double angle = 0, double inset = 0}) =>
        Transform.rotate(
          angle: angle,
          child: Container(
            width: MemoryMarker.bubble - inset,
            height: MemoryMarker.bubble - inset,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(OsdRadius.r14),
              border: Border.all(color: border, width: 2.5),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: PlacesColors.markerShadow,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: PlacePoster(clip: place.newest, radius: OsdRadius.r14),
          ),
        );
    final List<DiaryPlace> m = cluster.members;
    return SizedBox.square(
      dimension: MemoryMarker.bubble,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          if (m.length > 2) card(m[2], angle: .2, inset: 6),
          if (m.length > 1) card(m[1], angle: -.16, inset: 3),
          card(cluster.lead),
          if (cluster.clips > 1)
            PositionedDirectional(
              top: -7,
              end: -9,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.co,
                  borderRadius: BorderRadius.circular(OsdRadius.full),
                  border: Border.all(color: PlacesColors.space, width: 1.5),
                ),
                child: Text(
                  count,
                  style: context.typography.badge12.copyWith(
                    color: colors.onCo,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close(),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}
