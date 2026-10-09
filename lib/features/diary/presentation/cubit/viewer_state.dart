import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/domain/clip_caption.dart';
import 'package:one_second_diary/features/diary/domain/clip_filter.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';

/// Which way the viewer last moved (the video slides that way).
enum ViewerStep {
  /// Not moved yet.
  none,

  /// To a later clip.
  forward,

  /// To an earlier clip.
  backward,
}

/// Where a clip sits among its day's clips: [position] (1-based) of
/// [count] ("2 of 3").
typedef DayPosition = ({int position, int count});

/// The viewer: the clip shown and its neighbours, its caption, the sound,
/// and the last delete asked.
final class ViewerState extends Equatable {
  const ViewerState({
    required this.profile,
    required this.clip,
    required this.opened,
    this.index,
    this.filter = const ClipFilter.none(),
    this._filteredIndex,
    this.caption = ClipCaption.none,
    this.muted = false,
    this.deletion = ClipDeletion.idle,
    this.deletedClip,
    this.closed = false,
    this.step = ViewerStep.none,
    this.revealed = const <ClipRef>{},
    this.hidden = const <ClipRef>{},
  });

  /// The clip's profile (its orientation; its name in the delete dialog).
  final Profile profile;

  final ClipRef clip;

  /// The clip the viewer opened on.
  final ClipRef opened;

  /// The clip's profile's diary; null until read.
  final ClipIndex? index;

  /// The Diary's filter the viewer was opened with (empty from Today).
  final ClipFilter filter;

  final ClipIndex? _filteredIndex;

  /// The clips [filter] keeps of [index] ([index] itself without one):
  /// what Previous and Next step through. The cubit makes it once per
  /// snapshot.
  ClipIndex? get filteredIndex =>
      filter.isEmpty ? index : _filteredIndex ?? index;

  /// What [clip] says about itself (the place, the subtitle).
  final ClipCaption caption;

  /// The player plays without sound.
  final bool muted;

  /// The last delete asked, and its clip.
  final ClipDeletion deletion;
  final ClipRef? deletedClip;

  /// No clip is left to show: the viewer closes.
  final bool closed;

  final ViewerStep step;

  /// The private clips uncovered in this viewer by a tap on their cover,
  /// besides [opened].
  final Set<ClipRef> revealed;

  /// The clips marked private while shown: covered until tapped, [opened]
  /// too.
  final Set<ClipRef> hidden;

  /// Whether [clip]'s picture and caption are hidden: a private clip
  /// stepped to and not uncovered yet. Opening the viewer on a clip is
  /// choosing to watch it.
  bool isCovered(ClipRef clip) =>
      (index?.isPrivate(clip) ?? false) &&
      !revealed.contains(clip) &&
      (clip != opened || hidden.contains(clip));

  /// The clip before [clip] among the clips the filter keeps: an earlier
  /// clip of its day, else the last clip of the closest earlier recorded
  /// day; null at the first.
  ClipRef? get previous => filteredIndex?.previousClip(clip);

  /// The clip after [clip]; null at the last.
  ClipRef? get next => filteredIndex?.nextClip(clip);

  /// The viewer shows another clip than the one it opened on.
  bool get moved => clip != opened;

  /// Where [clip] sits among its day's clips (the ones the filter keeps).
  DayPosition get dayPosition {
    final List<ClipRef> clips =
        filteredIndex?.clipsOn(clip.day) ?? const <ClipRef>[];
    return (position: clips.indexOf(clip) + 1, count: clips.length);
  }

  /// This state with what is given; a new [index] comes with
  /// [filteredIndex], the clips the filter keeps of it.
  ViewerState copyWith({
    ClipRef? clip,
    ClipIndex? index,
    ClipIndex? filteredIndex,
    ClipCaption? caption,
    bool? muted,
    ClipDeletion? deletion,
    ClipRef? deletedClip,
    bool? closed,
    ViewerStep? step,
    Set<ClipRef>? revealed,
    Set<ClipRef>? hidden,
  }) => ViewerState(
    profile: profile,
    clip: clip ?? this.clip,
    opened: opened,
    index: index ?? this.index,
    filter: filter,
    filteredIndex: filteredIndex ?? _filteredIndex,
    caption: caption ?? this.caption,
    muted: muted ?? this.muted,
    deletion: deletion ?? this.deletion,
    deletedClip: deletedClip ?? this.deletedClip,
    closed: closed ?? this.closed,
    step: step ?? this.step,
    revealed: revealed ?? this.revealed,
    hidden: hidden ?? this.hidden,
  );

  @override
  List<Object?> get props => <Object?>[
    profile,
    clip,
    opened,
    index,
    filter,
    _filteredIndex,
    caption,
    muted,
    deletion,
    deletedClip,
    closed,
    step,
    revealed,
    hidden,
  ];
}
