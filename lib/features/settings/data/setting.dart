import 'dart:async';

/// One stored setting: its current [value], [set] to change it and
/// [changes] to follow it.
///
/// [value] is read from the preference store on every access (a cached copy
/// could drift from what is stored), and normalised (a clamp, a default for
/// an unknown value). [set] completes once the value is stored and then
/// announces the stored value; a refused write throws a `StorageException`
/// and announces nothing.
final class Setting<T> {
  Setting({required this._read, required this._write});

  final T Function() _read;
  final Future<void> Function(T value) _write;

  // App-scoped like its repository, so it is never closed.
  final StreamController<T> _changes = StreamController<T>.broadcast();

  T get value => _read();

  /// Stores [value], then announces the stored value on [changes].
  Future<void> set(T value) async {
    await _write(value);
    _changes.add(this.value);
  }

  /// The stored value after each [set], for listeners that read [value]
  /// first.
  Stream<T> get changes => _changes.stream;
}
