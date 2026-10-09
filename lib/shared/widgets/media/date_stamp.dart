import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_artwork.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

enum _DateStampVariant { onMedia, placeholder, preview, polaroid }

/// The date stamp as ffmpeg burns it into a clip: in the font the export
/// burns for its text (`StampFontPolicy`), one line, never scaled with the
/// text size, decorative (the date is in the header or label).
///
/// - [DateStamp.onMedia]: scaled with [videoWidth]; the user's stamp [color]
///   (white by default) with the contrast [outline]
///   (`OsdMedia.stampShadowFor`: black, or white for dark colours).
/// - [DateStamp.placeholder]: in FA, for an empty frame.
/// - [DateStamp.preview]: centred, scaled down to fit.
/// - [DateStamp.polaroid]: in the artwork ink.
class DateStamp extends StatelessWidget {
  const DateStamp.onMedia(
    this.text, {
    super.key,
    this.color = OsdMedia.onMedia,
    this.outline = true,
    this.videoWidth = 390,
  }) : _variant = _DateStampVariant.onMedia;

  const DateStamp.placeholder(this.text, {super.key})
    : _variant = _DateStampVariant.placeholder,
      color = null,
      outline = false,
      videoWidth = 390;

  const DateStamp.preview(
    this.text, {
    super.key,
    this.color = OsdMedia.onMedia,
    this.outline = true,
  }) : _variant = _DateStampVariant.preview,
       videoWidth = 390;

  const DateStamp.polaroid(this.text, {super.key})
    : _variant = _DateStampVariant.polaroid,
      color = OsdArtwork.ink,
      outline = false,
      videoWidth = 390;

  /// The formatted date, as the stamp burns it.
  final String text;

  /// The stamp colour (FA for the placeholder).
  final Color? color;

  /// Whether the contrast outline is on.
  final bool outline;

  /// The width of the video rect the stamp sits on.
  final double videoWidth;

  final _DateStampVariant _variant;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final color = this.color ?? context.colors.fa;
    final style = switch (_variant) {
      _DateStampVariant.onMedia => typography.stampMedia(
        texts: <String>[text],
        videoWidth: videoWidth,
      ),
      _DateStampVariant.placeholder => typography.stampPlaceholder(text),
      _DateStampVariant.preview => typography.stampPreview(text),
      _DateStampVariant.polaroid => typography.stampPolaroid(text),
    };
    final Widget stamp = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      textAlign: _variant == _DateStampVariant.preview
          ? TextAlign.center
          : null,
      textScaler: TextScaler.noScaling,
      style: style.copyWith(
        color: color,
        shadows: outline ? OsdMedia.stampShadowFor(color) : null,
      ),
    );
    return ExcludeSemantics(
      child: _variant == _DateStampVariant.preview
          ? FittedBox(fit: BoxFit.scaleDown, child: stamp)
          : stamp,
    );
  }
}
