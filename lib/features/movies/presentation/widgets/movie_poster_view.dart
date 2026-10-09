import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_ticket.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';

/// A movie's poster (its first frame) from [MoviePosters], drawn by the design
/// system's `ClipThumbnail`: in the movie tile slot (16:9, a portrait movie
/// contained over its blurred backdrop) or the player's (contained on black);
/// `broken_image` when it can't be made.
class MoviePosterView extends StatefulWidget {
  const MoviePosterView({
    super.key,
    required this.posters,
    required this.file,
    required this.orientation,
    this.radius = 0,
    this.slot = ClipThumbnailSlot.movieTile,
  });

  /// Where the posters come from (the route's `MoviePosters`).
  final MoviePosters posters;

  /// The movie's path in `Movies/`.
  final String file;

  /// Its shape; null while unknown (drawn landscape).
  final VideoOrientation? orientation;

  final double radius;

  /// How the poster fills its box.
  final ClipThumbnailSlot slot;

  @override
  State<MoviePosterView> createState() => _MoviePosterViewState();
}

class _MoviePosterViewState extends State<MoviePosterView> {
  MoviePosters get _posters => widget.posters;
  ThumbnailTicket? _ticket;
  String? _poster;
  bool _broken = false;

  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void didUpdateWidget(MoviePosterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file != oldWidget.file ||
        widget.orientation != oldWidget.orientation ||
        !identical(widget.posters, oldWidget.posters)) {
      _ticket?.cancel();
      _ticket = null;
      _broken = false;
      _ask();
    }
  }

  @override
  void dispose() {
    _ticket?.cancel();
    super.dispose();
  }

  void _ask() {
    final String? cached = _posters.cachedFile(
      widget.file,
      orientation: widget.orientation,
    );
    if (cached != null) {
      _poster = cached;
      return;
    }
    // Another movie never shows the old one's poster.
    _poster = null;
    final ThumbnailTicket ticket = _posters.request(
      widget.file,
      orientation: widget.orientation,
    );
    _ticket = ticket;
    unawaited(
      ticket.file.then((String? file) {
        if (!mounted || !identical(_ticket, ticket)) return;
        setState(() {
          _poster = file;
          _broken = file == null;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? poster = _poster;
    return ClipThumbnail(
      image: poster == null ? null : FileImage(File(poster)),
      slot: widget.slot,
      orientation: widget.orientation ?? VideoOrientation.landscape,
      radius: widget.radius,
      broken: _broken,
    );
  }
}
