import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/movies/data/movie_tag_reader.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';

/// A [MovieTagReader] that describes the movies in [answers] (by path in
/// `Movies/`) and leaves every other one as listed. With [hold], each read
/// waits for [releaseOne] or [releaseAll].
class FakeMovieTagReader extends Fake implements MovieTagReader {
  final Map<String, MovieEntry> answers = <String, MovieEntry>{};

  /// The paths read, in order.
  final List<String> reads = <String>[];

  bool hold = false;
  final List<Completer<void>> _held = <Completer<void>>[];

  /// Lets the oldest held read answer.
  void releaseOne() => _held.removeAt(0).complete();

  void releaseAll() {
    hold = false;
    for (final Completer<void> gate in _held) {
      gate.complete();
    }
    _held.clear();
  }

  @override
  Future<MovieEntry> read(MovieEntry movie) async {
    reads.add(movie.fileName);
    if (hold) {
      final Completer<void> gate = Completer<void>();
      _held.add(gate);
      await gate.future;
    }
    return answers[movie.fileName] ?? movie;
  }
}
