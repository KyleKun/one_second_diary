/// One request to `ThumbnailRepository`: the thumbnail's future path, and a
/// way to say it is no longer needed.
final class ThumbnailTicket {
  ThumbnailTicket({required this.file, required this._onCancel});

  /// The thumbnail's path once it exists; null when it could not be made.
  /// After [cancel] it may complete with null (dropped) or with the path
  /// (made anyway); a tile that went away ignores it.
  final Future<String?> file;

  final void Function() _onCancel;
  bool _cancelled = false;

  /// The tile went away (scrolled off, page closed). A generation that has
  /// not started is dropped unless another ticket still wants it; one that
  /// has started finishes and is cached. Calling it again does nothing.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel();
  }
}
