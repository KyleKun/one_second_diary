import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/today/domain/part_of_day.dart';

/// Whether Today knows the day's clips.
enum TodayStatus {
  /// The active profile's diary is being read: the frame shows its
  /// loading state, the controls wait.
  loading,

  /// [TodayState.clips] are the day's clips.
  ready,

  /// The diary could not be read. Today shows the empty day, so the user
  /// can still record.
  unavailable,
}

/// Today: the day, the active profile and the day's clips.
final class TodayState extends Equatable {
  TodayState({
    required this.day,
    required this.partOfDay,
    required this.profile,
    required this.stampFormat,
    List<ClipRef> clips = const <ClipRef>[],
    this.recordedDays = 0,
    this.lastRecordedDay,
    this.status = TodayStatus.loading,
    this.shownClip,
  }) : clips = List<ClipRef>.unmodifiable(clips);

  /// The local day Today is about.
  final LocalDay day;

  /// The part of the day the character greets by.
  final PartOfDay partOfDay;

  /// The profile new clips go to: its key and its shape. The chip names it
  /// from `ProfilesCubit`, whose Default name follows the app's language.
  final Profile profile;

  /// The day's clips in [profile], in recording order.
  final List<ClipRef> clips;

  /// How many days of [profile] have a clip (0 until its diary is read):
  /// the character's first-clip and milestone lines count them.
  final int recordedDays;

  /// The latest day of [profile] with a clip; null while its diary is
  /// read, or when it has none.
  final LocalDay? lastRecordedDay;

  /// The user's format, in which the empty frame previews the date stamp.
  final StampFormat stampFormat;

  final TodayStatus status;

  /// The clip the user brought into view; null for the latest.
  /// [visibleClip] is what shows.
  final ClipRef? shownClip;

  /// The clip in view, which Edit acts on: the one the user brought into
  /// view while the day still has it, else the latest; null when the day
  /// has none.
  ClipRef? get visibleClip => clips.contains(shownClip)
      ? shownClip
      : clips.isEmpty
      ? null
      : clips.last;

  TodayState copyWith({
    LocalDay? day,
    PartOfDay? partOfDay,
    Profile? profile,
    StampFormat? stampFormat,
    TodayStatus? status,
  }) => TodayState(
    day: day ?? this.day,
    partOfDay: partOfDay ?? this.partOfDay,
    profile: profile ?? this.profile,
    clips: clips,
    recordedDays: recordedDays,
    lastRecordedDay: lastRecordedDay,
    stampFormat: stampFormat ?? this.stampFormat,
    status: status ?? this.status,
    shownClip: shownClip,
  );

  /// This state with what the diary says: the day's [clips], the
  /// profile's [recordedDays] and its [lastRecordedDay].
  TodayState withDiary({
    required List<ClipRef> clips,
    required int recordedDays,
    required LocalDay? lastRecordedDay,
    required TodayStatus status,
    ClipRef? shownClip,
  }) => TodayState(
    day: day,
    partOfDay: partOfDay,
    profile: profile,
    clips: clips,
    recordedDays: recordedDays,
    lastRecordedDay: lastRecordedDay,
    stampFormat: stampFormat,
    status: status,
    shownClip: shownClip,
  );

  /// This state with [clip] in view; null for the latest clip.
  TodayState withShownClip(ClipRef? clip) => withDiary(
    clips: clips,
    recordedDays: recordedDays,
    lastRecordedDay: lastRecordedDay,
    status: status,
    shownClip: clip,
  );

  @override
  List<Object?> get props => <Object?>[
    day,
    partOfDay,
    profile,
    clips,
    recordedDays,
    lastRecordedDay,
    stampFormat,
    status,
    shownClip,
  ];
}
