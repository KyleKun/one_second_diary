import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// A [ProfileConversionStarter] answering [answer] to every estimate and
/// yielding [events] for every job (recorded in [jobs]); with [error] set,
/// the run's stream throws it instead. A job whose token is cancelled
/// before an event ends with a cancelled report instead of the rest.
final class FakeProfileConversionStarter implements ProfileConversionStarter {
  FakeProfileConversionStarter({
    this.answer = const ConversionEstimate(
      clipCount: 12,
      totalDurationMs: 24000,
      estimatedTime: Duration(minutes: 3),
      neededBytes: 1200 * 1000 * 1000,
      verdict: StorageOk(),
      sameFormat: false,
    ),
  });

  ConversionEstimate answer;

  /// What a run yields, in order.
  List<ConversionEvent> events = const <ConversionEvent>[
    ConversionProgress(
      done: 0,
      total: 12,
      fraction: 0,
      remaining: Duration(minutes: 3),
    ),
    ConversionFinished(
      ConversionReport(
        done: 12,
        total: 12,
        skipped: <ClipRef, ConversionSkipReason>{},
        cancelled: false,
      ),
    ),
  ];

  /// Thrown by the run's stream when set.
  Object? error;

  /// Every estimate asked for, as (source, format).
  final List<(ProfileKey, ClipFormat)> estimated = <(ProfileKey, ClipFormat)>[];

  /// Every job started.
  final List<ConversionJob> jobs = <ConversionJob>[];

  @override
  Future<ConversionEstimate> estimateConversion({
    required ProfileKey source,
    required ClipFormat format,
  }) async {
    estimated.add((source, format));
    return answer;
  }

  @override
  Stream<ConversionEvent> convertProfile(
    ConversionJob job, {
    CancelToken? cancelToken,
  }) async* {
    jobs.add(job);
    if (error case final Object error) throw error;
    int done = 0;
    for (final ConversionEvent event in events) {
      if (cancelToken?.isCancelled ?? false) {
        yield ConversionFinished(
          ConversionReport(
            done: done,
            total: answer.clipCount,
            skipped: const <ClipRef, ConversionSkipReason>{},
            cancelled: true,
          ),
        );
        return;
      }
      if (event is ConversionClipDone) done++;
      yield event;
    }
  }
}
