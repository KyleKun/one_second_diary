import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_ticket.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/clips/presentation/imports/imported_badge.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_foreign_watch.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_privacy_watch.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_tags_watch.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tag_badge.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';

/// A clip's poster, from the thumbnail cache: the design system's
/// [ClipThumbnail] fed by the `ThumbnailRepository`, for every screen that
/// shows clips.
///
/// - The clip's version is the one the `ClipRepository` index holds, looked up
///   when the view is built with a clip.
/// - A thumbnail the cache knows shows in the same frame. Any other shows the
///   slot's placeholder and is asked for, at the slot's tier ([tier], by
///   default [tierFor]); a poster not made yet shows the clip's cell thumbnail
///   meanwhile when known. Nothing blocks a frame: the image decodes off the
///   UI thread and fades in.
/// - The same clip rewritten in place keeps its old picture until the new one
///   is there; another clip never shows the old one.
/// - A request is cancelled when the view goes away or shows another clip, so
///   a flung grid never generates what scrolled past.
/// - A private clip's picture is blurred under a lock, unless [obscurePrivate]
///   is off. The view follows the clip's privacy itself.
/// - A tagged clip carries a small [TagBadge] in its top end corner where the
///   slot has room, unless [showTagBadge] is off or the picture is obscured.
/// - A clip the app did not make carries the "Imported" pill ([ImportedBadge])
///   in its bottom start corner, unless [showImportedBadge] is off or the
///   picture is obscured.
/// - Broken: the thumbnail could not be made or read, or the clip is not in
///   its profile's index. [onBrokenChanged] hears it (and hears it end), after
///   the frame.
///
/// Wrap grids of them in a `RepaintBoundary` and build them lazily
/// (`SliverGrid`, `GridView.builder`).
class ClipThumbnailView extends StatefulWidget {
  const ClipThumbnailView({
    super.key,
    required this.clip,
    required this.slot,
    this.orientation = VideoOrientation.landscape,
    this.tier,
    this.radius = 0,
    this.obscurePrivate = true,
    this.showTagBadge = true,
    this.showImportedBadge = true,
    this.overlay,
    this.placeholderOverlay,
    this.videoOverlay,
    this.semanticsLabel,
    this.onBrokenChanged,
  });

  final ClipRef clip;

  /// Where it sits (fit, glyphs and, by default, the tier).
  final ClipThumbnailSlot slot;

  /// The profile's orientation: the frame follows the profile.
  final VideoOrientation orientation;

  /// The size to ask for; [tierFor] the slot when null.
  final ThumbnailTier? tier;

  final double radius;

  /// Whether a private clip's picture is blurred.
  final bool obscurePrivate;

  /// Whether a tagged clip's picture carries the tag badge (a busy grid
  /// may leave it out).
  final bool showTagBadge;

  /// Whether a foreign clip's picture carries the "Imported" pill.
  final bool showImportedBadge;

  /// See `ClipThumbnail.overlay`.
  final Widget? overlay;

  /// See `ClipThumbnail.placeholderOverlay`.
  final Widget? placeholderOverlay;

  /// See `ClipThumbnail.videoOverlay`.
  final Widget? videoOverlay;

  final String? semanticsLabel;

  /// Whether the clip is broken, each time that changes (the first time
  /// only when it is).
  final ValueChanged<bool>? onBrokenChanged;

  /// The tier a slot shows: calendar cells and the small tiles take the
  /// cell size; players, frames and the viewer take the poster.
  static ThumbnailTier tierFor(ClipThumbnailSlot slot) => switch (slot) {
    ClipThumbnailSlot.calendarCell ||
    ClipThumbnailSlot.tile => ThumbnailTier.cell,
    ClipThumbnailSlot.todayFrame ||
    ClipThumbnailSlot.player ||
    ClipThumbnailSlot.movieTile ||
    ClipThumbnailSlot.savePreview ||
    ClipThumbnailSlot.viewer => ThumbnailTier.poster,
  };

  @override
  State<ClipThumbnailView> createState() => _ClipThumbnailViewState();
}

class _ClipThumbnailViewState extends State<ClipThumbnailView> {
  late final ClipRepository _clips = context.read<ClipRepository>();
  late final ThumbnailRepository _thumbnails = context
      .read<ThumbnailRepository>();
  late final ClipPrivacyWatch _privacy = ClipPrivacyWatch(
    clips: _clips,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );
  late final ClipTagsWatch _tags = ClipTagsWatch(
    clips: _clips,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );
  late final ClipForeignWatch _foreign = ClipForeignWatch(
    clips: _clips,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// The version and tier shown or asked for.
  ({ClipRef clip, FileStamp stamp, ThumbnailTier tier})? _wanted;
  ThumbnailTicket? _ticket;
  String? _file;
  bool _broken = false;

  /// What [ClipThumbnailView.onBrokenChanged] heard last.
  bool _reportedBroken = false;

  @override
  void initState() {
    super.initState();
    _privacy.watch(widget.clip);
    _tags.watch(widget.clip);
    _foreign.watch(widget.clip);
    _resolve();
  }

  @override
  void didUpdateWidget(ClipThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _privacy.watch(widget.clip);
    _tags.watch(widget.clip);
    _foreign.watch(widget.clip);
    _resolve();
  }

  @override
  void dispose() {
    _privacy.dispose();
    _tags.dispose();
    _foreign.dispose();
    _ticket?.cancel();
    super.dispose();
  }

  ThumbnailTier get _tier =>
      widget.tier ?? ClipThumbnailView.tierFor(widget.slot);

  /// Finds the clip's version and shows or asks for its thumbnail.
  void _resolve() {
    final ClipRef clip = widget.clip;
    final ClipIndex? index = _clips.snapshotOf(clip.profile);
    final FileStamp? stamp = index?.stampOf(clip);
    final bool sameClip = _wanted?.clip == clip;
    if (stamp == null) {
      _drop();
      _file = null;
      _broken = index != null;
      return;
    }
    final ThumbnailTier tier = _tier;
    final ({ClipRef clip, FileStamp stamp, ThumbnailTier tier}) wanted = (
      clip: clip,
      stamp: stamp,
      tier: tier,
    );
    if (wanted == _wanted) return;
    _drop();
    _wanted = wanted;
    _broken = false;
    final String? cached = _thumbnails.cachedFile(
      clip,
      stamp: stamp,
      tier: tier,
    );
    if (cached != null) {
      _file = cached;
      return;
    }
    final String? smaller = tier == ThumbnailTier.poster
        ? _thumbnails.cachedFile(clip, stamp: stamp, tier: ThumbnailTier.cell)
        : null;
    // The same clip keeps what it shows until the new version is there.
    if (!sameClip || _file == null) _file = smaller;
    final ThumbnailTicket ticket = _thumbnails.request(
      clip,
      stamp: stamp,
      tier: tier,
      orientation: widget.orientation,
    );
    _ticket = ticket;
    ticket.file.then((String? file) {
      if (!mounted || !identical(_ticket, ticket)) return;
      _ticket = null;
      setState(() {
        if (file != null) {
          _file = file;
        } else if (_file == null) {
          _broken = true;
        }
      });
    }).ignore();
  }

  void _drop() {
    _ticket?.cancel();
    _ticket = null;
    _wanted = null;
  }

  /// The picture of [file] could not be read.
  void _unreadable(String file) {
    if (!mounted || _file != file || _broken) return;
    setState(() => _broken = true);
  }

  /// Tells [ClipThumbnailView.onBrokenChanged] after this frame, when
  /// [_broken] changed since it heard last.
  void _report() {
    if (widget.onBrokenChanged == null || _broken == _reportedBroken) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _broken == _reportedBroken) return;
      _reportedBroken = _broken;
      widget.onBrokenChanged?.call(_broken);
    });
  }

  @override
  Widget build(BuildContext context) {
    _report();
    final String? file = _file;
    final bool obscured = widget.obscurePrivate && _privacy.isPrivate;
    final double? badge = widget.slot.tagBadgeSize;
    final bool tagged =
        widget.showTagBadge &&
        badge != null &&
        !obscured &&
        _tags.tags.isNotEmpty;
    final bool imported =
        widget.showImportedBadge &&
        badge != null &&
        !obscured &&
        _foreign.isForeign;
    final Widget? overlay = tagged || imported
        ? Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ?widget.overlay,
              if (tagged) TagBadge(size: badge),
              if (imported)
                PositionedDirectional(
                  bottom: badge / 2,
                  start: badge / 2,
                  child: IgnorePointer(child: ImportedBadge(size: badge)),
                ),
            ],
          )
        : widget.overlay;
    return ClipThumbnail(
      image: file == null ? null : FileImage(File(file)),
      slot: widget.slot,
      orientation: widget.orientation,
      radius: widget.radius,
      broken: _broken,
      obscured: obscured,
      overlay: overlay,
      placeholderOverlay: widget.placeholderOverlay,
      videoOverlay: widget.videoOverlay,
      semanticsLabel: widget.semanticsLabel,
      onLoadFailed: file == null ? null : () => _unreadable(file),
    );
  }
}
