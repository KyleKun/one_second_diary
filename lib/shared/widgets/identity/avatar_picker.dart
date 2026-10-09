import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/dashed_border.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/identity/osd_avatar.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_surface.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The profile photo picker of the profile sheets: an avatar (or, for a
/// profile being created, [AvatarPicker.placeholder]: a dashed circle with an
/// `add_a_photo` glyph), an edit badge at its bottom-end, then the [caption].
///
/// The whole picker is one button labelled with the caption; it opens the
/// photo sheet. When a new photo arrives the badge pops with a light impact.
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    required String this.name,
    this.photo,
    required this.caption,
    required this.onPressed,
    this.compactCaption = false,
  });

  /// The empty picker of a profile being created.
  const AvatarPicker.placeholder({
    super.key,
    required this.caption,
    required this.onPressed,
    this.compactCaption = true,
  }) : name = null,
       photo = null;

  /// The edit badge (its ring).
  static const Key badgeKey = Key('avatarPicker.badge');

  /// The badge's inner disc.
  static const Key badgeDiscKey = Key('avatarPicker.badgeDisc');

  static const Key placeholderKey = Key('avatarPicker.placeholder');

  static const Key placeholderIconKey = Key('avatarPicker.placeholderIcon');

  static const double _size = 96;

  /// The profile name (null shows the placeholder).
  final String? name;

  final ImageProvider? photo;

  final String caption;

  /// Opens the photo sheet.
  final VoidCallback? onPressed;

  /// Whether the caption uses the smaller style.
  final bool compactCaption;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker>
    with SingleTickerProviderStateMixin {
  static const Duration _pop = Duration(milliseconds: 260);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pop,
    value: 1,
  );

  late final Animation<double> _scale =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: 1.15,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 40,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1.15,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 60,
        ),
      ]).animate(_controller);

  @override
  void didUpdateWidget(AvatarPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final photo = widget.photo;
    if (photo != null && photo != oldWidget.photo) {
      unawaited(OsdHaptic.light.play());
      if (!OsdMotion.reduced(context)) {
        unawaited(_controller.forward(from: 0));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final name = widget.name;
    final photo = widget.photo;
    return OsdPressable(
      onTap: widget.onPressed,
      overlay: OsdPressOverlay.none,
      semanticsLabel: widget.caption,
      excludeChildSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: <Widget>[
          SizedBox.square(
            dimension: AvatarPicker._size,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                if (name == null)
                  DecoratedBox(
                    key: AvatarPicker.placeholderKey,
                    decoration: BoxDecoration(
                      color: colors.c2,
                      shape: BoxShape.circle,
                    ),
                    child: DashedBorder(
                      color: colors.fa,
                      shape: BoxShape.circle,
                      child: Center(
                        child: OsdIcon(
                          OsdIcons.addAPhoto,
                          key: AvatarPicker.placeholderIconKey,
                          size: 34,
                          color: colors.mu,
                        ),
                      ),
                    ),
                  )
                else
                  OsdAvatar(name: name, photo: photo, size: AvatarPicker._size),
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    key: AvatarPicker.badgeKey,
                    decoration: BoxDecoration(
                      color: OsdSurface.of(context).color(colors),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ScaleTransition(
                        scale: _scale,
                        child: DecoratedBox(
                          key: AvatarPicker.badgeDiscKey,
                          decoration: BoxDecoration(
                            color: colors.tx,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: 28,
                            child: Center(
                              child: OsdIcon(
                                photo == null
                                    ? OsdIcons.add
                                    : OsdIcons.photoCamera,
                                size: 17,
                                color: colors.bg,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            widget.caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                (widget.compactCaption
                        ? typography.caption13
                        : typography.label14)
                    .copyWith(color: colors.mu),
          ),
        ],
      ),
    );
  }
}
