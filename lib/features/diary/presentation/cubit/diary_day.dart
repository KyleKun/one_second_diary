import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

/// What a day of the calendar holds.
enum DiaryDayKind {
  /// At least one clip: the first clip's picture.
  recorded,

  /// A day from the profile's first clip through today without a clip.
  missed,

  /// After today: dimmed and not tappable.
  future,

  /// Before the profile's first clip: neutral, never counted as missed,
  /// and still selectable to import a clip.
  beforeFirstClip,

  /// A day through today while the diary is still being read.
  unknown,

  /// A recorded day none of whose clips the Diary's filter keeps: its
  /// picture faint, not selectable while the filter is on.
  filteredOut,
}

/// One cell of the calendar: all a cell needs, so a cell rebuilds only
/// when its own day changes (a tap changes two of them).
final class DiaryDay extends Equatable {
  const DiaryDay({
    required this.day,
    required this.kind,
    this.clip,
    this.stamp,
    this.clipCount = 0,
    this.isToday = false,
    this.isSelected = false,
  });

  final LocalDay day;
  final DiaryDayKind kind;

  /// The day's first clip (ordinal order) the filter keeps, or, for a
  /// [DiaryDayKind.filteredOut] day, its first clip; null for the other
  /// kinds.
  final ClipRef? clip;

  /// The version of [clip] the index holds: a clip rewritten in place (a
  /// subtitle edit) changes it, so its cell shows the new picture.
  final FileStamp? stamp;

  /// The day's clips the filter keeps (a day may hold several); every clip
  /// of a [DiaryDayKind.filteredOut] day.
  final int clipCount;

  final bool isToday;
  final bool isSelected;

  /// Whether a tap selects the day: any day through today once the diary
  /// has been read, but not a day the filter leaves out.
  bool get isSelectable => switch (kind) {
    DiaryDayKind.recorded ||
    DiaryDayKind.missed ||
    DiaryDayKind.beforeFirstClip => true,
    DiaryDayKind.future ||
    DiaryDayKind.unknown ||
    DiaryDayKind.filteredOut => false,
  };

  @override
  List<Object?> get props => <Object?>[
    day,
    kind,
    clip,
    stamp,
    clipCount,
    isToday,
    isSelected,
  ];
}
