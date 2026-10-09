import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';

/// The clips picked by hand for a movie, so a tile knows whether it is picked
/// in O(1).
final class ClipPicks extends Equatable {
  const ClipPicks.none() : clips = const <ClipRef>{};

  const ClipPicks._(this.clips);

  final Set<ClipRef> clips;

  int get count => clips.length;

  bool contains(ClipRef clip) => clips.contains(clip);

  /// [clip] picked, or unpicked when it was.
  ClipPicks toggle(ClipRef clip) =>
      contains(clip) ? removing(<ClipRef>[clip]) : adding(<ClipRef>[clip]);

  /// These picks and every clip of [more].
  ClipPicks adding(Iterable<ClipRef> more) =>
      ClipPicks._(Set<ClipRef>.of(clips)..addAll(more));

  /// These picks without any clip of [fewer].
  ClipPicks removing(Iterable<ClipRef> fewer) =>
      ClipPicks._(Set<ClipRef>.of(clips)..removeAll(fewer));

  /// The picks that pass [keep] (the clips still in the diary); this very
  /// selection when all do.
  ClipPicks where(bool Function(ClipRef clip) keep) =>
      clips.every(keep) ? this : ClipPicks._(clips.where(keep).toSet());

  @override
  List<Object?> get props => <Object?>[clips];
}
