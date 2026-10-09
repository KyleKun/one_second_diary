import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Where My movies' list is.
enum MyMoviesStatus {
  /// Reading `Movies/` (a skeleton shows after 150 ms).
  loading,

  /// Listed: the grid, or the empty state.
  ready,

  /// `Movies/` could not be read: Try again.
  failed,
}

/// What My movies tells the user in a snackbar, once per change of
/// [MyMoviesState.noticeId].
sealed class MyMoviesNotice extends Equatable {
  const MyMoviesNotice();

  @override
  List<Object?> get props => const <Object?>[];
}

/// "Movie deleted" / "3 movies deleted".
final class MoviesDeletedNotice extends MyMoviesNotice {
  const MoviesDeletedNotice(this.count);

  final int count;

  @override
  List<Object?> get props => <Object?>[count];
}

/// "Couldn't delete this movie": the phone refused (Android's consent for
/// a movie the app does not own, declined), and the movie stays.
final class MovieDeleteFailedNotice extends MyMoviesNotice {
  const MovieDeleteFailedNotice();
}

/// "This movie was deleted from your phone": it went from the gallery
/// after it was listed, and it leaves the list.
final class MovieFileMissingNotice extends MyMoviesNotice {
  const MovieFileMissingNotice();
}

/// "Music turned on" / "Music turned off": the one movie selected plays its
/// other audio track now.
final class MovieMusicSwappedNotice extends MyMoviesNotice {
  const MovieMusicSwappedNotice({required this.on});

  final bool on;

  @override
  List<Object?> get props => <Object?>[on];
}

/// "Couldn't change this movie's sound": the swap failed, and the movie
/// is as it was.
final class MovieMusicSwapFailedNotice extends MyMoviesNotice {
  const MovieMusicSwapFailedNotice();
}

/// How many movies a profile has in My movies: a choice of the profile filter.
final class MovieProfileCount extends Equatable {
  const MovieProfileCount({required this.profile, required this.count});

  final ProfileKey? profile;
  final int count;

  @override
  List<Object?> get props => <Object?>[profile, count];
}

/// My movies, its profile filter and its selection mode.
final class MyMoviesState extends Equatable {
  /// [visibleMovies] is worked out here: [movies] itself while [profileFilter]
  /// is empty, so a state that changes neither keeps the very list (the grid
  /// builds again only on another list).
  factory MyMoviesState({
    required MyMoviesStatus status,
    List<MovieEntry> movies = const <MovieEntry>[],
    Set<ProfileKey?> profileFilter = const <ProfileKey?>{},
    Set<String> selected = const <String>{},
    bool deleting = false,
    bool sharing = false,
    bool swappingMusic = false,
    bool largeView = false,
    MyMoviesNotice? notice,
    int noticeId = 0,
  }) => MyMoviesState._(
    status: status,
    movies: movies,
    profileFilter: profileFilter,
    visibleMovies: _visible(movies, profileFilter),
    selected: selected,
    deleting: deleting,
    sharing: sharing,
    swappingMusic: swappingMusic,
    largeView: largeView,
    notice: notice,
    noticeId: noticeId,
  );

  const MyMoviesState._({
    required this.status,
    required this.movies,
    required this.profileFilter,
    required this.visibleMovies,
    required this.selected,
    required this.deleting,
    required this.sharing,
    required this.swappingMusic,
    required this.largeView,
    required this.notice,
    required this.noticeId,
  });

  const MyMoviesState.loading({bool largeView = false})
    : this._(
        status: MyMoviesStatus.loading,
        movies: const <MovieEntry>[],
        profileFilter: const <ProfileKey?>{},
        visibleMovies: const <MovieEntry>[],
        selected: const <String>{},
        deleting: false,
        sharing: false,
        swappingMusic: false,
        largeView: largeView,
        notice: null,
        noticeId: 0,
      );

  final MyMoviesStatus status;

  /// Every movie, newest first.
  final List<MovieEntry> movies;

  /// The profiles whose movies show; empty shows every movie. A null entry
  /// keeps the movies that name no profile (made by an older install).
  final Set<ProfileKey?> profileFilter;

  /// The movies [profileFilter] keeps, newest first: the very [movies]
  /// while the filter is empty.
  final List<MovieEntry> visibleMovies;

  /// The paths in `Movies/` of the movies selected, in the order they were
  /// picked.
  final Set<String> selected;

  /// Whether the movies selected are being deleted (the dialog spins).
  final bool deleting;

  /// Whether the share sheet is being opened.
  final bool sharing;

  /// Whether the one movie selected is having its music turned off or on
  /// (the file is remuxed; the action waits).
  final bool swappingMusic;

  /// The one movie selected, when it has music (the music action is
  /// about it); null otherwise.
  MovieEntry? get musicMovie => switch (selectedMovies) {
    [final MovieEntry only] when only.hasMusic => only,
    _ => null,
  };

  /// Whether the movies show one large picture a row instead of the grid
  /// (the bar's toggle; remembered).
  final bool largeView;

  /// The last thing said; [noticeId] changes each time one is said.
  final MyMoviesNotice? notice;
  final int noticeId;

  /// Whether selection mode is on.
  bool get selecting => selected.isNotEmpty;

  /// Whether a profile filter is on.
  bool get isFiltered => profileFilter.isNotEmpty;

  /// Whether the filter keeps no movie (there are movies, none of them
  /// visible): "No movies match".
  bool get noMatches => movies.isNotEmpty && visibleMovies.isEmpty;

  /// The movies selected, in list order (visible ones only).
  List<MovieEntry> get selectedMovies => <MovieEntry>[
    for (final MovieEntry movie in visibleMovies)
      if (selected.contains(movie.fileName)) movie,
  ];

  /// How many movies each profile has, in the order their newest movie comes;
  /// the movies without a profile count under null, last.
  List<MovieProfileCount> get profileCounts {
    final Map<ProfileKey?, int> counts = <ProfileKey?, int>{};
    int older = 0;
    for (final MovieEntry movie in movies) {
      final ProfileKey? profile = movie.profile;
      if (profile == null) {
        older++;
      } else {
        counts[profile] = (counts[profile] ?? 0) + 1;
      }
    }
    return <MovieProfileCount>[
      for (final MapEntry<ProfileKey?, int> entry in counts.entries)
        MovieProfileCount(profile: entry.key, count: entry.value),
      if (older > 0) MovieProfileCount(profile: null, count: older),
    ];
  }

  MyMoviesState copyWith({
    MyMoviesStatus? status,
    List<MovieEntry>? movies,
    Set<ProfileKey?>? profileFilter,
    Set<String>? selected,
    bool? deleting,
    bool? sharing,
    bool? swappingMusic,
    bool? largeView,
  }) {
    final List<MovieEntry> nextMovies = movies ?? this.movies;
    final Set<ProfileKey?> nextFilter = profileFilter ?? this.profileFilter;
    final bool sameList =
        identical(nextMovies, this.movies) &&
        identical(nextFilter, this.profileFilter);
    return MyMoviesState._(
      status: status ?? this.status,
      movies: nextMovies,
      profileFilter: nextFilter,
      visibleMovies: sameList
          ? visibleMovies
          : _visible(nextMovies, nextFilter),
      selected: selected ?? this.selected,
      deleting: deleting ?? this.deleting,
      sharing: sharing ?? this.sharing,
      swappingMusic: swappingMusic ?? this.swappingMusic,
      largeView: largeView ?? this.largeView,
      notice: notice,
      noticeId: noticeId,
    );
  }

  /// This state saying [notice].
  MyMoviesState saying(MyMoviesNotice notice) => MyMoviesState._(
    status: status,
    movies: movies,
    profileFilter: profileFilter,
    visibleMovies: visibleMovies,
    selected: selected,
    deleting: deleting,
    sharing: sharing,
    swappingMusic: swappingMusic,
    largeView: largeView,
    notice: notice,
    noticeId: noticeId + 1,
  );

  static List<MovieEntry> _visible(
    List<MovieEntry> movies,
    Set<ProfileKey?> filter,
  ) => filter.isEmpty
      ? movies
      : List<MovieEntry>.unmodifiable(<MovieEntry>[
          for (final MovieEntry movie in movies)
            if (filter.contains(movie.profile)) movie,
        ]);

  @override
  List<Object?> get props => <Object?>[
    status,
    movies,
    profileFilter,
    selected,
    deleting,
    sharing,
    swappingMusic,
    largeView,
    notice,
    noticeId,
  ];
}
