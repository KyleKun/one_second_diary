import 'package:equatable/equatable.dart';

/// What a `TagBatch` run reports.
sealed class TagBatchEvent extends Equatable {
  const TagBatchEvent();
}

/// [done] of [total] clips rewritten so far (failures count as done).
final class TagBatchProgress extends TagBatchEvent {
  const TagBatchProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  List<Object?> get props => <Object?>[done, total];
}

/// The run ended: [updated] clips rewritten, [failed] left as they were,
/// and whether the user [stopped] it before the rest.
final class TagBatchFinished extends TagBatchEvent {
  const TagBatchFinished({
    required this.updated,
    required this.failed,
    required this.stopped,
  });

  final int updated;
  final int failed;
  final bool stopped;

  @override
  List<Object?> get props => <Object?>[updated, failed, stopped];
}
