import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/flow_profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_switch_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:one_second_diary/shared/widgets/identity/profile_chip.dart';

/// The profile chip of the movie flow: the profile the movie is made of.
class MovieProfileChip extends StatefulWidget {
  const MovieProfileChip({super.key});

  static const Key chipKey = Key('movieProfileChip.chip');

  @override
  State<MovieProfileChip> createState() => _MovieProfileChipState();
}

class _MovieProfileChipState extends State<MovieProfileChip> {
  bool _open = false;

  Future<void> _pick() async {
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    setState(() => _open = true);
    final ProfileKey? picked = await ProfileSwitchSheet.show(
      context,
      selected: flow.state.profile,
      title: Strings.createMovieFromProfile,
      // A profile created here would become the app's and has no clips.
      canCreate: false,
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null) flow.chooseProfile(picked);
  }

  @override
  Widget build(BuildContext context) {
    final Profile? profile = FlowProfile.watch(context);
    final String name =
        profile?.displayName ??
        context.read<CreateMovieCubit>().state.profile.value;
    return ProfileChip(
      key: MovieProfileChip.chipKey,
      name: name,
      photo: profile == null ? null : ProfileAvatar.photoOf(context, profile),
      maxNameWidth: 120,
      expanded: _open,
      semanticsLabel: Strings.movieProfileChipSemantics(name: name),
      semanticsTapHint: Strings.change,
      onPressed: () => unawaited(_pick()),
    );
  }
}
