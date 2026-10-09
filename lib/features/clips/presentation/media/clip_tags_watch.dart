import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';

/// Follows one clip's tags in the library, for a widget that shows them
/// without a cubit (`ClipThumbnailView`'s badge, a caption's chips): the
/// twin of `ClipPrivacyWatch`.
///
/// [watch] reads the tags at once and subscribes to the profile's
/// snapshots; [onChanged] is called when the watched clip's tags change
/// after that. [dispose] it with the widget.
class ClipTagsWatch {
  ClipTagsWatch({required this._clips, required this._onChanged});

  final ClipRepository _clips;
  final VoidCallback _onChanged;

  ClipRef? _clip;
  StreamSubscription<ClipIndex>? _snapshots;

  /// The watched clip's tags.
  List<String> get tags => _tags;
  List<String> _tags = const <String>[];

  /// Watches [clip], and says at once which tags it has.
  void watch(ClipRef clip) {
    final ClipRef? previous = _clip;
    _clip = clip;
    _tags = _clips.snapshotOf(clip.profile)?.tagsOf(clip) ?? const <String>[];
    if (previous?.profile == clip.profile && _snapshots != null) return;
    unawaited(_snapshots?.cancel());
    _snapshots = _clips
        .watch(clip.profile)
        .listen(
          _follow,
          // A failed scan: the screen shows it.
          onError: (Object _) {},
        );
  }

  void dispose() {
    unawaited(_snapshots?.cancel());
    _snapshots = null;
  }

  void _follow(ClipIndex index) {
    final ClipRef? clip = _clip;
    if (clip == null || index.profile != clip.profile) return;
    final List<String> tags = index.tagsOf(clip);
    if (listEquals(tags, _tags)) return;
    _tags = tags;
    _onChanged();
  }
}
