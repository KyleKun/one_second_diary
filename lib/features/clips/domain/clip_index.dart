import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/clips/domain/month_progress.dart';
import 'package:one_second_diary/features/clips/domain/sorted_epoch_days.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// An immutable snapshot of one profile's clips: the single answer to
/// "which clips exist" for every screen.
///
/// A day lookup is one hash lookup and every range or neighbour query is a
/// binary search over the sorted recorded days, so no query ever costs O(N).
///
/// Days are compared as `LocalDay.epochDay`, whole calendar days computed in
/// UTC, so no range drifts across a DST change. A day's date comes from the
/// clip's file name only (`ClipRef`), never from its folder.
///
/// Several files may name the same (day, ordinal), e.g. `2024-01-05.mp4` and
/// `Old/2024-01-05.mp4`. One of them is visible, the shallowest path counted
/// from the profile folder, ties going to the smallest relPath; the others
/// are [hiddenDuplicates]. They stay in the snapshot, so removing the visible
/// one brings the next back, exactly as a rescan would.
///
/// A clip may be private ([isPrivate]): it is a clip like any other for the
/// calendar and the statistics, and [shareable] is the snapshot without the
/// private ones, which a movie is made of unless the user includes them.
/// A clip may carry tags ([tagsOf]); [tagCounts] is the profile's
/// vocabulary and [filtered] / [where] give the snapshot of the clips that
/// match, with every query of this class still answering in O(log n).
/// A clip may be foreign ([isForeign]): a date-named file nobody made with
/// the app (its cached schema is `other`), badged "Imported" and offered for
/// processing; [foreignCount] counts the visible ones.
/// A clip may have a kept source ([hasSource]): its original recording sits
/// beside the diary under the clip's own name (a names-only scan of that
/// folder), so "Edit again" is offered for it without touching the disk.
///
/// Patches ([withClip], [withoutClip], [withPrivacy], [withPrivate],
/// [withTags], [withClipTags], [withForeign], [withSchema], [withSources],
/// [withSource]) return a new snapshot and leave this one untouched.
/// Equality is identity: a new instance means new content.
class ClipIndex {
  /// A snapshot of [clips], all of which must belong to [profile]. A relPath
  /// listed twice keeps its last entry. The files of [private] (relPaths)
  /// are private, those of [tags] carry the tags given (normalised by
  /// `TagName`), those of [foreign] were not made by the app, and those of
  /// [sources] have a kept original; a file not among [clips] is ignored
  /// in all four.
  factory ClipIndex({
    required ProfileKey profile,
    required Iterable<IndexedClip> clips,
    Set<String> private = const <String>{},
    Map<String, List<String>> tags = const <String, List<String>>{},
    Set<String> foreign = const <String>{},
    Set<String> sources = const <String>{},
  }) {
    final Map<String, IndexedClip> entries = <String, IndexedClip>{};
    for (final IndexedClip clip in clips) {
      _requireProfile(profile, clip.ref);
      entries[clip.ref.relPath] = clip;
    }
    return ClipIndex._build(
      profile,
      entries,
      private,
      tags,
      foreign: foreign,
      sources: sources,
    );
  }

  /// A profile with no clips (yet).
  factory ClipIndex.empty(ProfileKey profile) => ClipIndex._build(
    profile,
    const <String, IndexedClip>{},
    const <String>{},
    const <String, List<String>>{},
  );

  /// [tags] from outside are normalised; a snapshot's own map
  /// ([normalisedTags]) already is, so a sub-index only filters it.
  factory ClipIndex._build(
    ProfileKey profile,
    Map<String, IndexedClip> entries,
    Set<String> private,
    Map<String, List<String>> tags, {
    bool normalisedTags = false,
    Set<String> foreign = const <String>{},
    Set<String> sources = const <String>{},
  }) {
    final Map<(int, int), ClipRef> visible = <(int, int), ClipRef>{};
    final List<ClipRef> hidden = <ClipRef>[];
    for (final IndexedClip clip in entries.values) {
      final ClipRef ref = clip.ref;
      final (int, int) slot = (ref.day.epochDay, ref.ordinal);
      final ClipRef? other = visible[slot];
      if (other == null) {
        visible[slot] = ref;
      } else if (_precedes(ref, other)) {
        visible[slot] = ref;
        hidden.add(other);
      } else {
        hidden.add(ref);
      }
    }
    final Map<int, List<ClipRef>> byDay = <int, List<ClipRef>>{};
    for (final ClipRef ref in visible.values) {
      (byDay[ref.day.epochDay] ??= <ClipRef>[]).add(ref);
    }
    for (final MapEntry<int, List<ClipRef>> day in byDay.entries) {
      day.value.sort((ClipRef a, ClipRef b) => a.ordinal.compareTo(b.ordinal));
      byDay[day.key] = List<ClipRef>.unmodifiable(day.value);
    }
    final List<int> days = byDay.keys.toList()..sort();
    final List<int> clipsBefore = List<int>.filled(days.length + 1, 0);
    for (int i = 0; i < days.length; i++) {
      clipsBefore[i + 1] = clipsBefore[i] + byDay[days[i]]!.length;
    }
    hidden.sort((ClipRef a, ClipRef b) => a.relPath.compareTo(b.relPath));
    final Set<String> marked = _among(private, entries);
    final Set<String> foreignMarked = _among(foreign, entries);
    return ClipIndex._(
      profile: profile,
      entries: entries,
      days: List<int>.unmodifiable(days),
      byDay: byDay,
      clipsBefore: clipsBefore,
      hiddenDuplicates: List<ClipRef>.unmodifiable(hidden),
      private: marked,
      privateCount: _visibleAmong(marked, entries: entries, byDay: byDay),
      tags: _tagged(tags, entries: entries, normalised: normalisedTags),
      foreign: foreignMarked,
      foreignCount: _visibleAmong(
        foreignMarked,
        entries: entries,
        byDay: byDay,
      ),
      sources: _among(sources, entries),
    );
  }

  /// The members of [relPaths] that name a file of [entries].
  static Set<String> _among(
    Set<String> relPaths,
    Map<String, IndexedClip> entries,
  ) => relPaths.isEmpty
      ? const <String>{}
      : <String>{
          for (final String relPath in relPaths)
            if (entries.containsKey(relPath)) relPath,
        };

  ClipIndex._({
    required this.profile,
    required this._entries,
    required List<int> days,
    required this._byDay,
    required this._clipsBefore,
    required this.hiddenDuplicates,
    required this._private,
    required this.privateCount,
    required this._tags,
    required this._foreign,
    required this.foreignCount,
    required this._sources,
  }) : epochDays = days;

  final ProfileKey profile;

  /// Every file of the profile by relPath, hidden duplicates included.
  final Map<String, IndexedClip> _entries;

  /// The recorded days as `LocalDay.epochDay`s, sorted and unique. The
  /// Journey statistics run on this list.
  final List<int> epochDays;

  final Map<int, List<ClipRef>> _byDay;

  /// `_clipsBefore[i]` = clips on `epochDays[0..i)`, so the clips of any day
  /// range are two binary searches and a subtraction.
  final List<int> _clipsBefore;

  /// Files that name the same (day, ordinal) as a visible clip in a deeper
  /// or later-sorting folder, by relPath. They are never shown or put in a
  /// movie.
  final List<ClipRef> hiddenDuplicates;

  /// The relPaths of the files marked private, all of them in [_entries].
  final Set<String> _private;

  /// Visible clips that are private.
  final int privateCount;

  /// The tags of the files that have some, by relPath, all of them in
  /// [_entries]; a file without tags is absent.
  final Map<String, List<String>> _tags;

  /// The relPaths of the files not made by the app (cached schema
  /// `other`), all of them in [_entries].
  final Set<String> _foreign;

  /// Visible clips that are foreign ("12 imported videos").
  final int foreignCount;

  /// The relPaths of the files whose original recording is kept beside
  /// the diary, all of them in [_entries].
  final Set<String> _sources;

  /// Visible clips ("clips found", month counts).
  int get clipCount => _clipsBefore.last;

  /// Distinct recorded days ("days recorded").
  int get dayCount => epochDays.length;

  bool get isEmpty => epochDays.isEmpty;

  LocalDay? get firstDay =>
      epochDays.isEmpty ? null : LocalDay.fromEpochDay(epochDays.first);

  LocalDay? get lastDay =>
      epochDays.isEmpty ? null : LocalDay.fromEpochDay(epochDays.last);

  /// Whether [day] has a clip, in O(1).
  bool hasDay(LocalDay day) => _byDay.containsKey(day.epochDay);

  /// The visible clips of [day] in ordinal order (recording order).
  List<ClipRef> clipsOn(LocalDay day) =>
      _byDay[day.epochDay] ?? const <ClipRef>[];

  /// The stamp [clip] was seen with, or null when it is not in the index.
  FileStamp? stampOf(ClipRef clip) => _entries[clip.relPath]?.stamp;

  /// Whether [clip] is marked private, in O(1).
  bool isPrivate(ClipRef clip) => _private.contains(clip.relPath);

  /// Whether [clip] was not made by the app (badged "Imported"), in O(1).
  bool isForeign(ClipRef clip) => _foreign.contains(clip.relPath);

  /// Whether [clip]'s original recording is kept beside the diary, so
  /// "Edit again" is offered for it, in O(1).
  bool hasSource(ClipRef clip) => _sources.contains(clip.relPath);

  /// The visible foreign clips, newest first (what the processing sheet
  /// lists for this profile).
  List<ClipRef> get foreignClips => foreignCount == 0
      ? const <ClipRef>[]
      : <ClipRef>[
          for (final ClipRef ref in newestFirst)
            if (_foreign.contains(ref.relPath)) ref,
        ];

  /// The tags of [clip], in their stored order; empty when it has none or
  /// is not in the index. O(1).
  List<String> tagsOf(ClipRef clip) => _tags[clip.relPath] ?? const <String>[];

  /// Whether any file of the profile carries a tag.
  bool get hasTags => _tags.isNotEmpty;

  /// The profile's vocabulary: every tag of a visible clip with how many
  /// carry it, most used first, then by name. Tags are one per
  /// `TagName.fold`, named as first seen (newest clip first). Made once per
  /// snapshot.
  late final List<TagCount> tagCounts = _countTags();

  /// This snapshot without its private clips (this very snapshot when it
  /// has none): what a movie is made of unless the user includes them, so
  /// every count and range of a movie is still a binary search. Made once
  /// per snapshot. A duplicate a private clip hides stays hidden.
  late final ClipIndex shareable = privateCount == 0
      ? this
      : _visibleWhere((ClipRef ref) => !_private.contains(ref.relPath));

  /// The snapshot of the visible clips [filter] keeps (this very snapshot
  /// for an empty filter), with their privacy and tags, so a movie's
  /// `shareable` and every range count still work on it. A duplicate a
  /// filtered-out clip hides stays hidden.
  ClipIndex filtered(TagFilter filter) => filter.isEmpty
      ? this
      : _visibleWhere((ClipRef ref) => filter.matches(tagsOf(ref)));

  /// The snapshot of the visible clips [keep] says, with their privacy and
  /// tags (see [filtered]). O(n) once; the result answers like any index.
  ClipIndex where(bool Function(ClipRef clip) keep) => _visibleWhere(keep);

  ClipIndex _visibleWhere(bool Function(ClipRef clip) keep) {
    final Map<String, IndexedClip> kept = <String, IndexedClip>{
      for (final List<ClipRef> day in _byDay.values)
        for (final ClipRef ref in day)
          if (keep(ref)) ref.relPath: _entries[ref.relPath]!,
    };
    return ClipIndex._build(
      profile,
      kept,
      _private,
      _tags,
      normalisedTags: true,
      foreign: _foreign,
      sources: _sources,
    );
  }

  List<TagCount> _countTags() {
    if (_tags.isEmpty) return const <TagCount>[];
    final Map<String, String> names = <String, String>{};
    final Map<String, int> counts = <String, int>{};
    for (final ClipRef ref in newestFirst) {
      for (final String tag in tagsOf(ref)) {
        final String key = TagName.fold(tag);
        names.putIfAbsent(key, () => tag);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final List<TagCount> result =
        <TagCount>[
          for (final MapEntry<String, int> entry in counts.entries)
            TagCount(name: names[entry.key]!, count: entry.value),
        ]..sort((TagCount a, TagCount b) {
          final int byCount = b.count.compareTo(a.count);
          return byCount != 0
              ? byCount
              : TagName.fold(a.name).compareTo(TagName.fold(b.name));
        });
    return List<TagCount>.unmodifiable(result);
  }

  /// The ordinal of a new clip of [day]: 1 + the highest ordinal the day
  /// has anywhere in the profile, sub-folders included. So a new recording
  /// never takes the bare name of a day whose only clip sits in `trip/`,
  /// which would hide that clip.
  int nextOrdinal(LocalDay day) {
    final List<ClipRef>? clips = _byDay[day.epochDay];
    return clips == null ? 1 : clips.last.ordinal + 1;
  }

  /// The clip played before [clip]: an earlier clip of the same day, else
  /// the last clip of the closest earlier recorded day. [clip] need not be
  /// in the index (it may just have been deleted).
  ClipRef? previousClip(ClipRef clip) {
    final List<ClipRef>? sameDay = _byDay[clip.day.epochDay];
    if (sameDay != null) {
      for (int i = sameDay.length - 1; i >= 0; i--) {
        if (sameDay[i].ordinal < clip.ordinal) return sameDay[i];
      }
    }
    final int i = epochDays.indexAtOrAfter(clip.day.epochDay) - 1;
    return i >= 0 ? _byDay[epochDays[i]]!.last : null;
  }

  /// The clip played after [clip]: a later clip of the same day, else the
  /// first clip of the closest later recorded day.
  ClipRef? nextClip(ClipRef clip) {
    final List<ClipRef>? sameDay = _byDay[clip.day.epochDay];
    if (sameDay != null) {
      for (final ClipRef other in sameDay) {
        if (other.ordinal > clip.ordinal) return other;
      }
    }
    final int i = epochDays.indexAtOrAfter(clip.day.epochDay + 1);
    return i < epochDays.length ? _byDay[epochDays[i]]!.first : null;
  }

  /// The closest recorded day before [day].
  LocalDay? previousRecordedDay(LocalDay day) {
    final int i = epochDays.indexAtOrAfter(day.epochDay) - 1;
    return i >= 0 ? LocalDay.fromEpochDay(epochDays[i]) : null;
  }

  /// Recorded days of [year]-[month] through [today], out of the days of
  /// that month that have begun by [today] ("25 of 28 days").
  MonthProgress monthSummary({
    required int year,
    required int month,
    required LocalDay today,
  }) {
    final int first = _epochDay(year, month, 1);
    final int last = _epochDay(year, month + 1, 1) - 1;
    final int until = last < today.epochDay ? last : today.epochDay;
    return MonthProgress(
      recorded: epochDays.countBetween(first, until),
      elapsed: until < first ? 0 : until - first + 1,
    );
  }

  /// Clips (not days) of each month of [year]: element 0 is January.
  List<int> clipsPerMonth(int year) => <int>[
    for (int month = 1; month <= 12; month++)
      _clipsBetween(_epochDay(year, month, 1), _epochDay(year, month + 1, 1)),
  ];

  /// The clips of the days in [range], by day, then ordinal: the order a
  /// movie plays them in.
  List<ClipRef> clipsIn(DayRange range) {
    if (range.isEmpty) return const <ClipRef>[];
    final int from = epochDays.indexAtOrAfter(range.first.epochDay);
    final int until = epochDays.indexAtOrAfter(range.last.epochDay + 1);
    return <ClipRef>[
      for (int i = from; i < until; i++) ..._byDay[epochDays[i]]!,
    ];
  }

  /// How many clips [clipsIn] would return, in O(log n).
  int countClipsIn(DayRange range) => range.isEmpty
      ? 0
      : _clipsBetween(range.first.epochDay, range.last.epochDay + 1);

  /// The days of [range] without a clip, never after [today].
  List<LocalDay> skippedDays(DayRange range, {required LocalDay today}) {
    final int last = range.last.epochDay < today.epochDay
        ? range.last.epochDay
        : today.epochDay;
    return <LocalDay>[
      for (int day = range.first.epochDay; day <= last; day++)
        if (!_byDay.containsKey(day)) LocalDay.fromEpochDay(day),
    ];
  }

  /// Every visible clip, newest day first and, within a day, the latest
  /// clip first.
  Iterable<ClipRef> get newestFirst sync* {
    for (int i = epochDays.length - 1; i >= 0; i--) {
      yield* _byDay[epochDays[i]]!.reversed;
    }
  }

  /// This snapshot plus [clip], or with [clip]'s new stamp when its relPath
  /// is already known (a clip replaced in place).
  ///
  /// The file keeps its privacy and its tags: a clip rewritten in place is
  /// still private, still tagged.
  ClipIndex withClip(IndexedClip clip) {
    _requireProfile(profile, clip.ref);
    return ClipIndex._build(
      profile,
      <String, IndexedClip>{..._entries, clip.ref.relPath: clip},
      _private,
      _tags,
      foreign: _foreign,
      sources: _sources,
    );
  }

  /// This snapshot without the file at [relPath]; this very snapshot when
  /// the file is unknown. A duplicate it hid becomes visible.
  ClipIndex withoutClip(String relPath) {
    if (!_entries.containsKey(relPath)) return this;
    return ClipIndex._build(
      profile,
      Map<String, IndexedClip>.of(_entries)..remove(relPath),
      _private,
      _tags,
      foreign: _foreign,
      sources: _sources,
    );
  }

  /// This snapshot with the file at [relPath] carrying exactly [tags]
  /// (empty: none); this very snapshot when the file is unknown or already
  /// does. The files and their order do not change, so the new snapshot
  /// shares them.
  ClipIndex withTags(String relPath, List<String> tags) {
    if (!_entries.containsKey(relPath)) return this;
    final List<String> normalized = TagName.normalize(tags);
    final List<String> current = _tags[relPath] ?? const <String>[];
    if (_sameTags(current, normalized)) return this;
    final Map<String, List<String>> next = Map<String, List<String>>.of(_tags);
    if (normalized.isEmpty) {
      next.remove(relPath);
    } else {
      next[relPath] = normalized;
    }
    return _remarked(private: _private, tags: next);
  }

  /// This snapshot with exactly the tags of [tagsByRelPath] on its files
  /// (a file not listed has none); this very snapshot when it already has.
  ClipIndex withClipTags(Map<String, List<String>> tagsByRelPath) {
    final Map<String, List<String>> next = _tagged(
      tagsByRelPath,
      entries: _entries,
    );
    if (next.length == _tags.length &&
        next.entries.every(
          (MapEntry<String, List<String>> entry) =>
              _sameTags(_tags[entry.key] ?? const <String>[], entry.value),
        )) {
      return this;
    }
    return _remarked(private: _private, tags: next);
  }

  /// This snapshot with the file at [relPath] marked private, or public;
  /// this very snapshot when the file is unknown or already is. The files
  /// and their order do not change, so the new snapshot shares them.
  ClipIndex withPrivacy(String relPath, {required bool private}) {
    if (!_entries.containsKey(relPath) ||
        _private.contains(relPath) == private) {
      return this;
    }
    return _remarked(
      private: private
          ? <String>{..._private, relPath}
          : (Set<String>.of(_private)..remove(relPath)),
      tags: _tags,
    );
  }

  /// This snapshot with exactly its files among [relPaths] marked private;
  /// this very snapshot when they already are.
  ClipIndex withPrivate(Set<String> relPaths) {
    final Set<String> marked = <String>{
      for (final String relPath in relPaths)
        if (_entries.containsKey(relPath)) relPath,
    };
    if (marked.length == _private.length && marked.containsAll(_private)) {
      return this;
    }
    return _remarked(private: marked, tags: _tags);
  }

  /// This snapshot with the file at [relPath] marked foreign, or the app's
  /// own; this very snapshot when the file is unknown or already is.
  ClipIndex withSchema(String relPath, {required bool foreign}) {
    if (!_entries.containsKey(relPath) ||
        _foreign.contains(relPath) == foreign) {
      return this;
    }
    return _remarked(
      private: _private,
      tags: _tags,
      foreign: foreign
          ? <String>{..._foreign, relPath}
          : (Set<String>.of(_foreign)..remove(relPath)),
    );
  }

  /// This snapshot with exactly its files among [relPaths] marked foreign;
  /// this very snapshot when they already are.
  ClipIndex withForeign(Set<String> relPaths) {
    final Set<String> marked = _among(relPaths, _entries);
    if (marked.length == _foreign.length && marked.containsAll(_foreign)) {
      return this;
    }
    return _remarked(private: _private, tags: _tags, foreign: marked);
  }

  /// This snapshot with the file at [relPath] marked as having a kept
  /// source, or not; this very snapshot when the file is unknown or
  /// already is.
  ClipIndex withSource(String relPath, {required bool has}) {
    if (!_entries.containsKey(relPath) || _sources.contains(relPath) == has) {
      return this;
    }
    return _remarked(
      private: _private,
      tags: _tags,
      sources: has
          ? <String>{..._sources, relPath}
          : (Set<String>.of(_sources)..remove(relPath)),
    );
  }

  /// This snapshot with exactly its files among [relPaths] marked as
  /// having a kept source (the Originals folder's names scan); this very
  /// snapshot when they already are.
  ClipIndex withSources(Set<String> relPaths) {
    final Set<String> marked = _among(relPaths, _entries);
    if (marked.length == _sources.length && marked.containsAll(_sources)) {
      return this;
    }
    return _remarked(private: _private, tags: _tags, sources: marked);
  }

  ClipIndex _remarked({
    required Set<String> private,
    required Map<String, List<String>> tags,
    Set<String>? foreign,
    Set<String>? sources,
  }) => ClipIndex._(
    profile: profile,
    entries: _entries,
    days: epochDays,
    byDay: _byDay,
    clipsBefore: _clipsBefore,
    hiddenDuplicates: hiddenDuplicates,
    private: private,
    privateCount: _visibleAmong(private, entries: _entries, byDay: _byDay),
    tags: tags,
    foreign: foreign ?? _foreign,
    foreignCount: foreign == null
        ? foreignCount
        : _visibleAmong(foreign, entries: _entries, byDay: _byDay),
    sources: sources ?? _sources,
  );

  /// The visible clips that [previous] did not show with the same stamp:
  /// new or rewritten files, and duplicates a removal made visible. Newest
  /// first, like [newestFirst].
  ///
  /// For the queues fed every snapshot (metadata and thumbnail backfills),
  /// so a save costs them the clips it changed, not a pass over every clip.
  /// A clip whose privacy, tags, schema or source alone changed is the
  /// same file: not listed.
  /// A patch shares every unchanged entry with the snapshot it came from, so
  /// an unchanged clip costs two hash lookups and an identity check; a
  /// rescan's new entries are compared by value.
  List<ClipRef> changedSince(ClipIndex previous) {
    final Set<String> wasHidden = <String>{
      for (final ClipRef ref in previous.hiddenDuplicates) ref.relPath,
    };
    final List<ClipRef> changed = <ClipRef>[];
    for (int i = epochDays.length - 1; i >= 0; i--) {
      final List<ClipRef> day = _byDay[epochDays[i]]!;
      for (int j = day.length - 1; j >= 0; j--) {
        final ClipRef ref = day[j];
        final IndexedClip entry = _entries[ref.relPath]!;
        final IndexedClip? before = previous._entries[ref.relPath];
        final bool same = identical(before, entry) || before == entry;
        if (!same || wasHidden.contains(ref.relPath)) changed.add(ref);
      }
    }
    return changed;
  }

  /// Whether [other] holds the same files with the same stamps (a rescan
  /// that found nothing new).
  bool hasSameFilesAs(ClipIndex other) {
    if (other.profile != profile || other._entries.length != _entries.length) {
      return false;
    }
    for (final MapEntry<String, IndexedClip> entry in _entries.entries) {
      if (other._entries[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Clips on the days in [fromDay, untilDay) (epoch days, end exclusive).
  int _clipsBetween(int fromDay, int untilDay) =>
      _clipsBefore[epochDays.indexAtOrAfter(untilDay)] -
      _clipsBefore[epochDays.indexAtOrAfter(fromDay)];

  /// The epoch day of [year]-[month]-[day], rolling [month] 13 over into
  /// the next year. Computed in UTC, so it never drifts across DST.
  static int _epochDay(int year, int month, int day) =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// The entries of [tags] that name a file, normalised (unless already
  /// [normalised]: a snapshot's own map), those with no tag left out.
  static Map<String, List<String>> _tagged(
    Map<String, List<String>> tags, {
    required Map<String, IndexedClip> entries,
    bool normalised = false,
  }) {
    if (tags.isEmpty) return const <String, List<String>>{};
    final Map<String, List<String>> tagged = <String, List<String>>{};
    for (final MapEntry<String, List<String>> entry in tags.entries) {
      if (!entries.containsKey(entry.key)) continue;
      final List<String> normalized = normalised
          ? entry.value
          : TagName.normalize(entry.value);
      if (normalized.isNotEmpty) tagged[entry.key] = normalized;
    }
    return tagged;
  }

  static bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// How many of the files of [private] are visible clips.
  static int _visibleAmong(
    Set<String> private, {
    required Map<String, IndexedClip> entries,
    required Map<int, List<ClipRef>> byDay,
  }) {
    int visible = 0;
    for (final String relPath in private) {
      final ClipRef ref = entries[relPath]!.ref;
      if (byDay[ref.day.epochDay]?.contains(ref) ?? false) visible++;
    }
    return visible;
  }

  /// Whether [a] wins over [b] for the same (day, ordinal): the shallower
  /// path, then the smaller relPath.
  static bool _precedes(ClipRef a, ClipRef b) {
    final int byDepth = _depth(a.relPath).compareTo(_depth(b.relPath));
    return byDepth != 0 ? byDepth < 0 : a.relPath.compareTo(b.relPath) < 0;
  }

  static int _depth(String relPath) => '/'.allMatches(relPath).length;

  static void _requireProfile(ProfileKey profile, ClipRef clip) {
    if (clip.profile != profile) {
      throw ArgumentError.value(
        clip.relPath,
        'clip',
        'belongs to profile "${clip.profile.value}", not "${profile.value}"',
      );
    }
  }
}
