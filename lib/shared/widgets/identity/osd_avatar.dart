import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A profile avatar: a circle of [size] showing the [photo], or the name's
/// first grapheme uppercased.
///
/// The photo is decoded at size × DPR, keeps its old frame while a new one
/// loads (`gaplessPlayback`) and fades in above the initial. A photo that
/// fails to load leaves the initial. The avatar is excluded from semantics:
/// the name always sits next to it.
class OsdAvatar extends StatelessWidget {
  const OsdAvatar({
    super.key,
    required this.name,
    this.photo,
    required this.size,
  });

  static const Key circleKey = Key('osdAvatar.circle');

  static const Key initialKey = Key('osdAvatar.initial');

  static const Key photoKey = Key('osdAvatar.photo');

  final String name;

  final ImageProvider? photo;

  /// The diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final characters = name.trim().characters;
    final initial = characters.isEmpty ? '' : characters.first.toUpperCase();
    final photo = this.photo;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          key: circleKey,
          decoration: BoxDecoration(color: colors.off, shape: BoxShape.circle),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Center(
                  child: Text(
                    initial,
                    key: initialKey,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    textScaler: OsdTextScale.scalerFor(
                      context,
                      OsdTextScaleRole.display,
                    ),
                    style: context.typography
                        .displayInitial(size)
                        .copyWith(color: colors.tx),
                  ),
                ),
                if (photo != null)
                  Image(
                    key: photoKey,
                    image: ResizeImage(
                      photo,
                      width: (size * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                    ),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, synchronous) =>
                        synchronous
                        ? child
                        : AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: OsdMotion.d(context, OsdMotion.fast),
                            curve: OsdMotion.fastCurve,
                            child: child,
                          ),
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
