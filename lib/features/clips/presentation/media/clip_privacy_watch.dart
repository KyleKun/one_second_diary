import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';

/// Whether the clip a media widget shows is private, kept current: the
/// widget follows its profile's snapshots itself, so a clip marked private
/// is blurred at once on every screen that shows it, whether or not that
/// screen rebuilds.
///
/// [watch] the widget's clip when it is built and whenever it changes;
/// [onChanged] is called when the watched clip's privacy changes after
/// that. [dispose] it with the widget.
class ClipPrivacyWatch {
  ClipPrivacyWatch({required this._clips, required this._onChanged});

  final ClipRepository _clips;
  final VoidCallback _onChanged;

  ClipRef? _clip;
  StreamSubscription<ClipIndex>? _snapshots;

  /// Whether the watched clip is private.
  bool get isPrivate => _isPrivate;
  bool _isPrivate = false;

  /// Watches [clip], and says at once whether it is private.
  void watch(ClipRef clip) {
    final ClipRef? previous = _clip;
    _clip = clip;
    _isPrivate = _clips.snapshotOf(clip.profile)?.isPrivate(clip) ?? false;
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
    final bool isPrivate = index.isPrivate(clip);
    if (isPrivate == _isPrivate) return;
    _isPrivate = isPrivate;
    _onChanged();
  }
}
