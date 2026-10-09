import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';

/// The profile a movie of the flow is made of, as the app's profiles
/// describe it: its name and orientation.
abstract final class FlowProfile {
  /// The flow's profile; null when the app's profiles do not list it.
  /// Rebuilds [context] when either changes.
  static Profile? watch(BuildContext context) {
    final ProfileKey key = context.select<CreateMovieCubit, ProfileKey>(
      (CreateMovieCubit flow) => flow.state.profile,
    );
    return context.select<ProfilesCubit, Profile?>(
      (ProfilesCubit profiles) => profiles.state.profiles
          .where((Profile profile) => profile.key == key)
          .firstOrNull,
    );
  }
}
