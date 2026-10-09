import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/tag_batch_event.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';

/// What a tag batch does to the clips concerned.
enum TagBatchKind { rename, remove }

/// A rename, merge or removal running (or just run) over every clip that
/// carries [tag]: [done] of [total] clips rewritten, and the outcome once
/// [finished].
final class TagBatchRun extends Equatable {
  const TagBatchRun({
    required this.kind,
    required this.tag,
    this.done = 0,
    this.total = 0,
    this.finished,
  });

  final TagBatchKind kind;

  /// The tag the batch started from.
  final String tag;

  final int done;

  final int total;

  /// The outcome; null while the batch runs.
  final TagBatchFinished? finished;

  bool get isRunning => finished == null;

  /// Progress, 0 to 1 (0 while the clips are not counted yet).
  double get progress => total == 0 ? 0 : done / total;

  TagBatchRun copyWith({int? done, int? total, TagBatchFinished? finished}) =>
      TagBatchRun(
        kind: kind,
        tag: tag,
        done: done ?? this.done,
        total: total ?? this.total,
        finished: finished ?? this.finished,
      );

  @override
  List<Object?> get props => <Object?>[kind, tag, done, total, finished];
}

/// Settings › Tags: every tag of every loaded profile with its clip count,
/// the batch running over the clips (if any), and a counter that grows
/// each time a tag's colour changes, so chips repaint.
final class TagsState extends Equatable {
  const TagsState({
    this.tags = const <TagCount>[],
    this.loaded = false,
    this.colorsVersion = 0,
    this.colorSaveFailures = 0,
    this.batch,
  });

  /// Most used first (`ClipTags.vocabulary`).
  final List<TagCount> tags;

  /// Whether [tags] has been read at least once (an empty list before that
  /// is "not read yet", not "no tags").
  final bool loaded;

  /// Grows each time a tag's colour changes.
  final int colorsVersion;

  /// Grows each time a colour could not be stored (the page says so).
  final int colorSaveFailures;

  /// The batch running, or the last one until the next starts.
  final TagBatchRun? batch;

  bool get hasTags => tags.isNotEmpty;

  bool get isBatchRunning => batch?.isRunning ?? false;

  TagsState copyWith({
    List<TagCount>? tags,
    bool? loaded,
    int? colorsVersion,
    int? colorSaveFailures,
    TagBatchRun? batch,
    bool clearBatch = false,
  }) => TagsState(
    tags: tags ?? this.tags,
    loaded: loaded ?? this.loaded,
    colorsVersion: colorsVersion ?? this.colorsVersion,
    colorSaveFailures: colorSaveFailures ?? this.colorSaveFailures,
    batch: clearBatch ? null : (batch ?? this.batch),
  );

  @override
  List<Object?> get props => <Object?>[
    tags,
    loaded,
    colorsVersion,
    colorSaveFailures,
    batch,
  ];
}
