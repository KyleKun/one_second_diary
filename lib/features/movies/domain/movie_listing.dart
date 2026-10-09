import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';

/// Every movie in `Movies/` (`MovieRepository.listing`), and which of them
/// the movie index knows nothing about.
final class MovieListing extends Equatable {
  const MovieListing({required this.movies, required this.unindexed});

  /// Newest first.
  final List<MovieEntry> movies;

  /// The paths in `Movies/` of the [movies] listed from their file alone (made
  /// by older installs, copied in, or made before a reinstall lost the index):
  /// their tags are read once (`MovieTagReader`).
  final Set<String> unindexed;

  @override
  List<Object?> get props => <Object?>[movies, unindexed];
}
