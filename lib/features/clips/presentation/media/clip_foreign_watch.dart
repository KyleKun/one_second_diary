import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';

/// Whether the clip a media widget shows is foreign (not made by the app,
/// badged "Imported"), kept current from its profile's snapshots, as
/// `ClipPrivacyWatch` keeps the privacy: a clip processed into the app's
/// own loses its badge at once on every screen that shows it.
///
/// [watch] the widget's clip when it is built and whenever it changes;
/// [onChanged] is called when the watched clip's flag changes after that.
/// [dispose] it with the widget.
class ClipForeignWatch {
  ClipForeignWatch({required this._clips, required this._onChanged});

  final ClipRepository _clips;
  final VoidCallback _onChanged;

  ClipRef? _clip;
  StreamSubscription<ClipIndex>? _snapshots;

  /// Whether the watched clip is foreign.
  bool get isForeign => _isForeign;
  bool _isForeign = false;

  /// Watches [clip], and says at once whether it is foreign.
  void watch(ClipRef clip) {
    final ClipRef? previous = _clip;
    _clip = clip;
    _isForeign = _clips.snapshotOf(clip.profile)?.isForeign(clip) ?? false;
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
    final bool isForeign = index.isForeign(clip);
    if (isForeign == _isForeign) return;
    _isForeign = isForeign;
    _onChanged();
  }
}
