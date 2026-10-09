import 'dart:async';

import 'package:one_second_diary/features/clips/data/thumbnail_ticket.dart';

/// A thumbnail job a background source hands to [ThumbnailQueue]: its
/// [key] (shared with requests for the same picture) and the work that
/// makes it.
typedef ThumbnailWork = ({Object key, Future<String?> Function() make});

/// The one queue in front of the thumbnail plugin, shared by the clips'
/// thumbnails (`ThumbnailRepository`) and the movie posters
/// (`MoviePosters`), so the phone never decodes more than [maxRunning]
/// frames at once, whoever asks.
///
/// - Requests ([request]) go first, the latest first: the tiles on screen
///   now, not the ones flung past. Requests with one key share one job, and
///   a request can be cancelled until its job starts; one that started
///   finishes.
/// - Background work (a source added with [addBackground]) starts only
///   while no request waits, and never in the last slot, so a tile always
///   starts at once instead of waiting behind 100-300 ms generations.
///
/// A job's `make` gives the picture's path, or null (it logs its own
/// failures).
final class ThumbnailQueue {
  ThumbnailQueue({this.maxRunning = 3}) : assert(maxRunning >= 2);

  final int maxRunning;

  int get _maxBackground => maxRunning - 1;

  /// Jobs not finished yet, by key.
  final Map<Object, _Job> _jobs = <Object, _Job>{};

  /// Requested jobs waiting for a slot; the last one starts first.
  final List<_Job> _waiting = <_Job>[];

  /// Where background work comes from, asked in order.
  final List<ThumbnailWork? Function()> _sources =
      <ThumbnailWork? Function()>[];

  int _running = 0;

  /// Background jobs among [_running].
  int _runningBackground = 0;

  /// Whether a job for [key] is waiting or running.
  bool isPending(Object key) => _jobs.containsKey(key);

  /// Asks for the picture [key], made by [make] unless a job for it is
  /// already pending. Cancel the ticket when the tile goes away.
  ThumbnailTicket request(Object key, Future<String?> Function() make) {
    _Job? job = _jobs[key];
    if (job == null) {
      job = _jobs[key] = _Job(key, make, background: false);
      _waiting.add(job);
      _startWaiting();
    }
    job.tickets++;
    final _Job wanted = job;
    return ThumbnailTicket(
      file: wanted.done.future,
      onCancel: () => _cancel(wanted),
    );
  }

  /// Adds a source of background work: [next] gives the next job, or null
  /// when it has none for now (call [pump] once it has more).
  void addBackground(ThumbnailWork? Function() next) {
    _sources.add(next);
    _startWaiting();
  }

  /// A background source has new work: starts it if a slot is free.
  void pump() => _startWaiting();

  /// A tile went away: a job no other tile wants and not started yet is
  /// dropped.
  void _cancel(_Job job) {
    job.tickets--;
    if (job.tickets > 0 || !_waiting.remove(job)) return;
    _jobs.remove(job.key);
    job.done.complete(null);
  }

  void _startWaiting() {
    while (_running < maxRunning && _waiting.isNotEmpty) {
      _start(_waiting.removeLast());
    }
    while (_waiting.isEmpty &&
        _running < maxRunning &&
        _runningBackground < _maxBackground) {
      final ThumbnailWork? work = _nextBackground();
      if (work == null) return;
      _start(_jobs[work.key] = _Job(work.key, work.make, background: true));
    }
  }

  ThumbnailWork? _nextBackground() {
    for (final ThumbnailWork? Function() next in _sources) {
      final ThumbnailWork? work = next();
      if (work != null) return work;
    }
    return null;
  }

  void _start(_Job job) {
    _running++;
    if (job.background) _runningBackground++;
    unawaited(_run(job));
  }

  Future<void> _run(_Job job) async {
    String? made;
    try {
      made = await job.make();
    } finally {
      job.done.complete(made);
      _jobs.remove(job.key);
      _running--;
      if (job.background) _runningBackground--;
      _startWaiting();
    }
  }
}

/// A picture being made, or waiting for a slot.
final class _Job {
  _Job(this.key, this.make, {required this.background});

  final Object key;
  final Future<String?> Function() make;

  /// Started by a background source (counted against its slots), not by a
  /// request.
  final bool background;

  final Completer<String?> done = Completer<String?>();

  /// Tickets not cancelled.
  int tickets = 0;
}
