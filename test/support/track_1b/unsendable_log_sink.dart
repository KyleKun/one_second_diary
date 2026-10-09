import 'dart:async';

import '../memory_log_sink.dart';

/// A [MemoryLogSink] that cannot cross an isolate boundary, like the app's
/// file sink (it holds async state). A service whose `Isolate.run` closure
/// captures `this` (and so its logger) fails with it, where a plain
/// [MemoryLogSink] would be copied silently.
class UnsendableLogSink extends MemoryLogSink {
  /// Async state, which the VM refuses to send to another isolate.
  final Completer<void> pending = Completer<void>();
}
