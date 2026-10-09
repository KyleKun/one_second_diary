import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/share_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';

/// The movie just made, and Share.
final class MovieCreatedState extends Equatable {
  const MovieCreatedState({
    required this.movie,
    required this.orientation,
    required this.poster,
    required this.showsLocation,
    this.skippedClips = 0,
    this.leftOutPrivateClips = 0,
    this.sharing = false,
  });

  /// The movie; null when the page opened without one (a stale location).
  final MovieEntry? movie;

  /// Its canvas (the preview's shape).
  final VideoOrientation orientation;

  /// Its first clip, whose poster is the movie's first frame.
  final ClipRef? poster;

  /// Whether the page says where the movie was saved (Android's
  /// DCIM/OneSecondDiary/Movies; iOS keeps it in the app's Files folder).
  final bool showsLocation;

  /// How many clips could not be read and are not in the movie; the page
  /// says so when there are any.
  final int skippedClips;

  /// How many private clips the movie was made without, which the confirmation
  /// had counted (their files were read only during the build); the page says
  /// so when there are any.
  final int leftOutPrivateClips;

  /// Whether the share sheet is being opened or is open.
  final bool sharing;

  MovieCreatedState copyWith({bool? sharing}) => MovieCreatedState(
    movie: movie,
    orientation: orientation,
    poster: poster,
    showsLocation: showsLocation,
    skippedClips: skippedClips,
    leftOutPrivateClips: leftOutPrivateClips,
    sharing: sharing ?? this.sharing,
  );

  @override
  List<Object?> get props => <Object?>[
    movie,
    orientation,
    poster,
    showsLocation,
    skippedClips,
    leftOutPrivateClips,
    sharing,
  ];
}

/// The finished job's movie, taken once when the created page opens and kept
/// while it shows (Done ends the job, and the page still shows its movie as it
/// leaves); it also handles Share.
class MovieCreatedCubit extends Cubit<MovieCreatedState> {
  MovieCreatedCubit({
    required MovieJobState job,
    required this._share,
    required this._paths,
    required bool showsLocation,
  }) : super(
         MovieCreatedState(
           movie: job.movie,
           orientation: job.request?.orientation ?? VideoOrientation.landscape,
           poster: job.movie == null ? null : job.clips.firstOrNull,
           showsLocation: showsLocation,
           skippedClips: job.movie == null ? 0 : job.skippedClips,
           leftOutPrivateClips: job.movie == null ? 0 : job.leftOutPrivateClips,
         ),
       );

  final ShareGateway _share;
  final AppPaths _paths;

  /// Opens the system share sheet with the movie's file, anchored to [origin]
  /// (the button, which iPad needs). A tap while it opens does nothing.
  Future<void> share({Rect? origin}) async {
    final MovieEntry? movie = state.movie;
    if (movie == null || state.sharing) return;
    emit(state.copyWith(sharing: true));
    await _share.shareFiles(<String>[
      '${_paths.movies}${movie.fileName}',
    ], origin: origin);
    if (!isClosed) emit(state.copyWith(sharing: false));
  }
}
