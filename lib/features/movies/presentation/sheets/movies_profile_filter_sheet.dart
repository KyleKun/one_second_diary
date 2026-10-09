import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_state.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/identity/osd_avatar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// My movies' "Filter by profile" sheet: one row per profile that has movies
/// (its picture, its CURRENT name and how many), then "Movies without a
/// profile" for the ones made by an older install, any number of them chosen;
/// Clear and Done.
class MoviesProfileFilterSheet extends StatefulWidget {
  const MoviesProfileFilterSheet({
    super.key,
    required this.choices,
    required this.initial,
    this.onChanged,
  });

  static const Key bodyKey = Key('moviesProfileFilterSheet.body');
  static const Key doneKey = Key('moviesProfileFilterSheet.done');
  static const Key clearKey = Key('moviesProfileFilterSheet.clear');

  /// The row of [profile] (null: "Movies without a profile").
  static Key rowKey(ProfileKey? profile) =>
      ValueKey<String?>('moviesProfileFilterSheet.row.${profile?.value}');

  /// The profiles that have movies (`MyMoviesState.profileCounts`).
  final List<MovieProfileCount> choices;

  final Set<ProfileKey?> initial;

  /// Hears every change while the sheet is open.
  final ValueChanged<Set<ProfileKey?>>? onChanged;

  /// Shows the sheet over [context]; resolves with the profiles chosen, or
  /// null when dismissed.
  static Future<Set<ProfileKey?>?> show(
    BuildContext context, {
    required List<MovieProfileCount> choices,
    required Set<ProfileKey?> initial,
    ValueChanged<Set<ProfileKey?>>? onChanged,
  }) => showOsdSheet<Set<ProfileKey?>>(
    context,
    title: Strings.movieFilterByProfile,
    height: OsdSheetHeight.tall,
    child: MoviesProfileFilterSheet(
      key: bodyKey,
      choices: choices,
      initial: initial,
      onChanged: onChanged,
    ),
  );

  /// The name a choice shows: the CURRENT display name of [profile], its key
  /// when no such profile exists any more, or "Movies without a profile" for
  /// null.
  static String nameOf(BuildContext context, ProfileKey? profile) {
    if (profile == null) return Strings.movieFilterNoProfile;
    return _profileOf(context, profile)?.displayName ?? profile.value;
  }

  static Profile? _profileOf(BuildContext context, ProfileKey key) =>
      context.select<ProfilesCubit, Profile?>(
        (ProfilesCubit profiles) => profiles.state.profiles
            .where((Profile profile) => profile.key == key)
            .firstOrNull,
      );

  @override
  State<MoviesProfileFilterSheet> createState() =>
      _MoviesProfileFilterSheetState();
}

class _MoviesProfileFilterSheetState extends State<MoviesProfileFilterSheet> {
  late Set<ProfileKey?> _chosen = widget.initial;

  static const double _avatar = 36;

  void _set(Set<ProfileKey?> chosen) {
    final Set<ProfileKey?> next = Set<ProfileKey?>.unmodifiable(chosen);
    setState(() => _chosen = next);
    widget.onChanged?.call(next);
  }

  void _toggle(ProfileKey? profile) => _set(
    _chosen.contains(profile)
        ? (<ProfileKey?>{..._chosen}..remove(profile))
        : <ProfileKey?>{..._chosen, profile},
  );

  /// The choices in the app's profile order, then the profiles that no
  /// longer exist, then the movies without a profile.
  List<MovieProfileCount> _ordered(List<Profile> profiles) {
    final Map<ProfileKey, int> order = <ProfileKey, int>{
      for (final (int index, Profile profile) in profiles.indexed)
        profile.key: index,
    };
    int rank(MovieProfileCount choice) => switch (choice.profile) {
      null => profiles.length + 1,
      final ProfileKey key => order[key] ?? profiles.length,
    };
    return List<MovieProfileCount>.of(widget.choices)
      ..sort((MovieProfileCount a, MovieProfileCount b) => rank(a) - rank(b));
  }

  @override
  Widget build(BuildContext context) {
    final List<Profile> profiles = context.select<ProfilesCubit, List<Profile>>(
      (ProfilesCubit profiles) => profiles.state.profiles,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s16,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: OsdSpace.s8,
          children: <Widget>[
            for (final MovieProfileCount choice in _ordered(profiles))
              _Row(
                choice: choice,
                profile: switch (choice.profile) {
                  null => null,
                  final ProfileKey key =>
                    profiles
                        .where((Profile profile) => profile.key == key)
                        .firstOrNull,
                },
                avatarSize: _avatar,
                chosen: _chosen.contains(choice.profile),
                onTap: () => _toggle(choice.profile),
              ),
          ],
        ),
        if (_chosen.isNotEmpty)
          OsdTextButton(
            key: MoviesProfileFilterSheet.clearKey,
            label: Strings.diaryFilterClear,
            tone: OsdTextButtonTone.secondary,
            onPressed: () => _set(const <ProfileKey?>{}),
          ),
        PrimaryButton(
          key: MoviesProfileFilterSheet.doneKey,
          label: Strings.done,
          onPressed: () => Navigator.of(context).pop(_chosen),
        ),
      ],
    );
  }
}

/// One choice: the profile's picture and name (or the "without a profile"
/// glyph), "N movies", and a check while chosen.
class _Row extends StatelessWidget {
  const _Row({
    required this.choice,
    required this.profile,
    required this.avatarSize,
    required this.chosen,
    required this.onTap,
  });

  final MovieProfileCount choice;

  /// The profile [choice] names, when it still exists.
  final Profile? profile;
  final double avatarSize;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ProfileKey? owner = choice.profile;
    final Profile? profile = this.profile;
    final String name = switch (owner) {
      null => Strings.movieFilterNoProfile,
      final ProfileKey key => profile?.displayName ?? key.value,
    };
    return OsdListRow(
      key: MoviesProfileFilterSheet.rowKey(owner),
      title: name,
      value: Strings.movieFilterMatches(
        choice.count,
        format: MovieLabels.numberFormat(context),
      ),
      icon: owner == null ? OsdIcons.personOff : null,
      leading: owner == null
          ? null
          : OsdAvatar(
              name: name,
              photo: profile == null
                  ? null
                  : ProfileAvatar.photoOf(context, profile),
              size: avatarSize,
            ),
      trailing: chosen
          ? const OsdRowTrailing.check()
          : const OsdRowTrailing.none(),
      checked: chosen,
      onTap: onTap,
    );
  }
}
