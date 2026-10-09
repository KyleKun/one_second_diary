import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// How a clip's poster fills its box.
enum ClipFit {
  /// Fills the box, cropping the overflow (centred).
  cover,

  /// Fits inside the box over the letterbox backdrop.
  containOverBackdrop,

  /// Fits inside the box on black.
  containOnBlack,
}

/// Where a [ClipThumbnail] sits, which decides the aspect rules and the
/// loading and error glyphs.
enum ClipThumbnailSlot {
  /// A calendar cell: cover.
  calendarCell,

  /// The Today frame and carousel page: cover (the frame takes the profile's
  /// shape).
  todayFrame,

  /// The Diary's mini player and memory card: portrait posters are contained
  /// over the backdrop.
  player,

  /// A picker tile, mosaic cell or processing thumb: cover.
  tile,

  /// The movie grid: portrait posters are contained over the backdrop.
  movieTile,

  /// The save preview: portrait is contained over the backdrop.
  savePreview,

  /// The viewer: portrait is contained on black.
  viewer;

  /// How a poster of a profile with [orientation] fills this slot.
  ClipFit fitFor(VideoOrientation orientation) {
    if (orientation == VideoOrientation.landscape) return ClipFit.cover;
    return switch (this) {
      calendarCell || todayFrame || tile => ClipFit.cover,
      player || movieTile || savePreview => ClipFit.containOverBackdrop,
      viewer => ClipFit.containOnBlack,
    };
  }

  /// The box's width / height for a profile with [orientation], or null when
  /// the layout fixes the height (calendar cells, players, the portrait save
  /// preview).
  double? aspectRatio(VideoOrientation orientation) {
    final landscape = orientation == VideoOrientation.landscape;
    return switch (this) {
      calendarCell || player => null,
      todayFrame || viewer => landscape ? 16 / 9 : 9 / 16,
      tile => landscape ? 16 / 9 : 174 / 300,
      movieTile => 16 / 9,
      savePreview => landscape ? 16 / 9 : null,
    };
  }

  /// The lock on a private clip's blurred picture.
  double get _lockSize => switch (this) {
    calendarCell => 14,
    tile || movieTile => 22,
    player || todayFrame || savePreview || viewer => 32,
  };

  /// The glyph of the tag badge in a corner of a tagged clip's picture, or
  /// null where the box is too small for one (a calendar cell).
  double? get tagBadgeSize => switch (this) {
    calendarCell => null,
    tile || movieTile => 12,
    player || todayFrame || savePreview || viewer => 14,
  };

  double get _brokenSize => switch (this) {
    calendarCell => 16,
    tile || movieTile => 28,
    player => 30,
    todayFrame || savePreview || viewer => 32,
  };

  bool get _brokenMuted => this == tile || this == movieTile;

  bool get _showsLoadingGlyph =>
      this == todayFrame || this == savePreview || this == player;
}

/// A clip's poster frame, orientation-aware.
///
/// It fills the box its parent gives it ([ClipThumbnailSlot.aspectRatio]),
/// clipped to [radius]. The poster is decoded once at its own size
/// ([maxDecodeSide] at most), so a box that changes size (a hero flight)
/// keeps its picture, and the previous frame stays while a new one loads.
/// Portrait posters in players, movie tiles and the save preview sit over a
/// blurred, scrimmed copy of themselves; in the viewer, on black.
///
/// - **Loading** (or [image] null): C2, plus a `movie` glyph in large
///   frames; [overlay] and [videoOverlay] appear once the poster is ready.
/// - **Error** (a failed load, or [broken]): C2 and `broken_image`; overlays
///   stay hidden. A failed load also tells [onLoadFailed], after the frame.
/// - **Obscured** (a private clip): blurred past recognition under a dark
///   scrim with a lock; the overlays stay.
///
/// [overlay] covers the box; [placeholderOverlay] covers it while loading and
/// on error. [videoOverlay] covers the contained frame when letterboxed
/// (stamps belong there). Decorative unless [semanticsLabel] is given.
class ClipThumbnail extends StatelessWidget {
  const ClipThumbnail({
    super.key,
    required this.image,
    required this.slot,
    this.orientation = VideoOrientation.landscape,
    this.radius = 0,
    this.broken = false,
    this.obscured = false,
    this.overlay,
    this.placeholderOverlay,
    this.videoOverlay,
    this.semanticsLabel,
    this.onLoadFailed,
  });

  /// A poster read from [path].
  ClipThumbnail.file(
    String path, {
    super.key,
    required this.slot,
    this.orientation = VideoOrientation.landscape,
    this.radius = 0,
    this.broken = false,
    this.obscured = false,
    this.overlay,
    this.placeholderOverlay,
    this.videoOverlay,
    this.semanticsLabel,
    this.onLoadFailed,
  }) : image = FileImage(File(path));

  /// The loading surface.
  static const Key placeholderKey = Key('clipThumbnail.placeholder');

  /// The error surface.
  static const Key brokenKey = Key('clipThumbnail.broken');

  static const Key imageKey = Key('clipThumbnail.image');

  /// The blurred letterbox backdrop.
  static const Key backdropKey = Key('clipThumbnail.backdrop');

  /// The lock over an [obscured] poster.
  static const Key lockKey = Key('clipThumbnail.lock');

  /// The longest side a poster is decoded at.
  ///
  /// A decode keyed on the box's width would be a new decode at every size,
  /// and a flight lays the poster out at a new size every frame: the picture
  /// would fade out for the whole flight.
  static const int maxDecodeSide = 720;

  static const Duration _fadeIn = Duration(milliseconds: 180);
  static const Color _backdropScrim = Color(0x59000000);
  static const Color _obscuredScrim = Color(0x66000000);

  /// The poster; null while its path is still unknown.
  final ImageProvider? image;

  final ClipThumbnailSlot slot;

  /// The profile's orientation (the frame follows the profile, not the
  /// file).
  final VideoOrientation orientation;

  final double radius;

  /// Whether the clip is known to be unreadable.
  final bool broken;

  /// Whether the poster must not be recognisable (a private clip).
  final bool obscured;

  /// Drawn over the whole box once the poster is ready.
  final Widget? overlay;

  /// Drawn over the whole box until then, and over the error surface.
  final Widget? placeholderOverlay;

  /// Drawn over the video rect once the poster is ready.
  final Widget? videoOverlay;

  /// A semantics label, when the thumbnail stands alone.
  final String? semanticsLabel;

  /// The [image] could not be read (a corrupt or vanished file): called
  /// after the frame that shows the error, so the owner may rebuild.
  final VoidCallback? onLoadFailed;

  @override
  Widget build(BuildContext context) {
    final label = semanticsLabel;
    final Widget body = LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth && constraints.hasBoundedHeight,
          'ClipThumbnail needs a bounded box: size it, or use '
          'AspectRatio(aspectRatio: slot.aspectRatio(orientation)).',
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: _Body(thumbnail: this, size: constraints.biggest),
        );
      },
    );
    return label == null
        ? ExcludeSemantics(child: body)
        : Semantics(
            image: true,
            label: label,
            child: ExcludeSemantics(child: body),
          );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.thumbnail, required this.size});

  final ClipThumbnail thumbnail;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final slot = thumbnail.slot;
    final image = thumbnail.image;
    final placeholderOverlay = thumbnail.placeholderOverlay;
    if (thumbnail.broken) {
      return _Covered(
        overlay: placeholderOverlay,
        child: _Broken(slot: slot),
      );
    }
    final placeholder = ColoredBox(
      key: ClipThumbnail.placeholderKey,
      color: colors.c2,
      child: slot._showsLoadingGlyph
          ? Center(child: OsdIcon(OsdIcons.movie, size: 32, color: colors.fa))
          : null,
    );
    if (image == null) {
      return _Covered(overlay: placeholderOverlay, child: placeholder);
    }

    final fit = slot.fitFor(thumbnail.orientation);
    final poster = ResizeImage(
      image,
      width: ClipThumbnail.maxDecodeSide,
      height: ClipThumbnail.maxDecodeSide,
      policy: ResizeImagePolicy.fit,
    );
    final clipAspect = thumbnail.orientation == VideoOrientation.landscape
        ? const Size(16, 9)
        : const Size(9, 16);
    final videoRect = fit == ClipFit.cover
        ? Offset.zero & size
        : Alignment.center.inscribe(
            applyBoxFit(BoxFit.contain, clipAspect, size).destination,
            Offset.zero & size,
          );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        placeholder,
        Image(
          key: ClipThumbnail.imageKey,
          image: poster,
          fit: fit == ClipFit.cover ? BoxFit.cover : BoxFit.contain,
          alignment: Alignment.center,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, synchronous) {
            final ready = synchronous || frame != null;
            final overlay = thumbnail.overlay;
            final videoOverlay = thumbnail.videoOverlay;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                AnimatedOpacity(
                  opacity: ready ? 1 : 0,
                  duration: synchronous
                      ? Duration.zero
                      : OsdMotion.d(context, ClipThumbnail._fadeIn),
                  curve: OsdMotion.fastCurve,
                  child: _Obscured(
                    obscured: thumbnail.obscured,
                    size: size,
                    lockSize: slot._lockSize,
                    child: switch (fit) {
                      ClipFit.cover => child,
                      ClipFit.containOnBlack => ColoredBox(
                        color: OsdMedia.letterbox,
                        child: child,
                      ),
                      ClipFit.containOverBackdrop => Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          _Backdrop(poster: poster, width: size.width),
                          child,
                        ],
                      ),
                    },
                  ),
                ),
                if (ready && videoOverlay != null)
                  Positioned.fromRect(rect: videoRect, child: videoOverlay),
                ?(ready ? overlay : placeholderOverlay),
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) {
            final onLoadFailed = thumbnail.onLoadFailed;
            if (onLoadFailed != null) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => onLoadFailed(),
              );
            }
            return _Covered(
              overlay: placeholderOverlay,
              child: _Broken(slot: slot),
            );
          },
        ),
      ],
    );
  }
}

/// [child] with [overlay] over it, when there is one.
class _Covered extends StatelessWidget {
  const _Covered({required this.overlay, required this.child});

  final Widget? overlay;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Stack(fit: StackFit.expand, children: <Widget>[child, ?overlay]);
}

/// [child], blurred past recognition under a scrim with a lock when
/// [obscured]. It stays in the tree either way, so a clip marked private or
/// public keeps its decoded picture.
class _Obscured extends StatelessWidget {
  const _Obscured({
    required this.obscured,
    required this.size,
    required this.lockSize,
    required this.child,
  });

  final bool obscured;
  final Size size;
  final double lockSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!obscured) return child;
    // Wide enough that faces and text are gone at any box size.
    final sigma = math.max(6, size.shortestSide * .09).toDouble();
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
          child: child,
        ),
        const ColoredBox(color: ClipThumbnail._obscuredScrim),
        Center(
          child: OsdIcon(
            OsdIcons.lock,
            key: ClipThumbnail.lockKey,
            size: lockSize,
            fill: 1,
            color: OsdMedia.onMedia,
          ),
        ),
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.poster, required this.width});

  final ImageProvider poster;
  final double width;

  @override
  Widget build(BuildContext context) {
    final sigma = math.max(8, 24 * width / 358).toDouble();
    return Stack(
      key: ClipThumbnail.backdropKey,
      fit: StackFit.expand,
      children: <Widget>[
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Image(
            image: poster,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
        const ColoredBox(color: ClipThumbnail._backdropScrim),
      ],
    );
  }
}

class _Broken extends StatelessWidget {
  const _Broken({required this.slot});

  final ClipThumbnailSlot slot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.c2,
      child: Center(
        child: OsdIcon(
          OsdIcons.brokenImage,
          key: ClipThumbnail.brokenKey,
          size: slot._brokenSize,
          color: slot._brokenMuted ? colors.mu : colors.fa,
        ),
      ),
    );
  }
}
