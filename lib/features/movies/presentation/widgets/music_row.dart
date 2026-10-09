import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_slider.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_action_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The confirmation's "Music" row: the music for this movie (none by default),
/// which opens a sheet to add audio files from the phone, see and remove them,
/// keep or drop the videos' own sound and set the music volume.
class MusicRow extends StatelessWidget {
  const MusicRow({super.key});

  /// The row.
  static const Key rowKey = Key('musicRow.row');

  /// The sheet's "Add music files".
  static const Key addKey = Key('musicRow.add');

  /// The sheet's "Keep the videos' sound" switch row.
  static const Key keepSoundKey = Key('musicRow.keepSound');

  /// The sheet's volume slider.
  static const Key volumeKey = Key('musicRow.volume');

  /// The sheet's row of the track at [index].
  static Key trackKey(int index) => ValueKey<String>('musicRow.track.$index');

  /// The remove button of the track at [index].
  static Key removeKey(int index) => ValueKey<String>('musicRow.remove.$index');

  /// "50%": the volume as the row and the slider say it.
  static String volumeLabel(double volume) => Strings.movieMusicVolumePercent(
    percent: (volume * 100).round().toString(),
  );

  /// What the row says under "Music": None, or "2 tracks · 50%".
  static String subtitleOf(BuildContext context, MovieMusic? music) =>
      music == null
      ? Strings.movieMusicNone
      : Strings.movieMusicSummary(
          tracks: Strings.movieMusicTracks(
            music.tracks.length,
            format: MovieLabels.numberFormat(context),
          ),
          volume: volumeLabel(music.volume),
        );

  static Future<void> _open(BuildContext context) {
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    return showOsdSheet<void>(
      context,
      title: Strings.movieMusicSheetTitle,
      // The sheet is pushed on the root navigator, above the flow's
      // provider: hand the flow down.
      child: BlocProvider<CreateMovieCubit>.value(
        value: flow,
        child: const MusicSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MovieMusic? music = context.select<CreateMovieCubit, MovieMusic?>(
      (CreateMovieCubit flow) => flow.state.music,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: OsdCard(
        child: OsdListRow(
          key: rowKey,
          icon: OsdIcons.volumeUp,
          title: Strings.movieMusic,
          subtitle: subtitleOf(context, music),
          trailing: const OsdRowTrailing.chevron(),
          haptic: OsdHaptic.selection,
          onTap: () => unawaited(_open(context)),
        ),
      ),
    );
  }
}

/// The music sheet: the tracks (each with Remove), "Add music files", the loop
/// note (or "No file was added" after a pick that gave nothing), and, with at
/// least one track, the keep-sound switch and the volume slider.
class MusicSheet extends StatefulWidget {
  const MusicSheet({super.key});

  /// The volume slider's steps: 5 % each.
  static const int volumeDivisions = 20;

  /// "No file was added", after a pick that gave nothing.
  static const Key noneAddedKey = Key('musicSheet.noneAdded');

  @override
  State<MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<MusicSheet> {
  /// Whether the last pick gave nothing (a cancel, or no readable file).
  bool _noneAdded = false;

  Future<void> _add() async {
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    final bool added = await flow.addMusic();
    if (mounted) setState(() => _noneAdded = !added);
  }

  @override
  Widget build(BuildContext context) {
    final (MovieMusic? music, Map<String, String> names) = context
        .select<CreateMovieCubit, (MovieMusic?, Map<String, String>)>(
          (CreateMovieCubit flow) => (flow.state.music, flow.state.musicNames),
        );
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s8,
      children: <Widget>[
        if (music != null)
          OsdCard(
            child: Column(
              children: <Widget>[
                for (final (int index, String track)
                    in music.tracks.indexed) ...<Widget>[
                  if (index > 0) const OsdDivider(),
                  OsdListRow(
                    key: MusicRow.trackKey(index),
                    title: names[track] ?? PathNames.fileNameOf(track),
                    trailing: OsdRowTrailing.custom(
                      OsdIconButton(
                        key: MusicRow.removeKey(index),
                        icon: OsdIcons.close,
                        tooltip: Strings.movieMusicRemoveTrack(
                          name: names[track] ?? PathNames.fileNameOf(track),
                        ),
                        onPressed: () => context
                            .read<CreateMovieCubit>()
                            .removeMusicTrack(index),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        OsdActionRow(
          key: MusicRow.addKey,
          icon: OsdIcons.add,
          label: Strings.movieMusicAddTracks,
          tone: OsdActionRowTone.primary,
          onTap: () => unawaited(_add()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _noneAdded
                ? Strings.movieMusicNoneAdded
                : Strings.movieMusicLoopNote,
            key: _noneAdded ? MusicSheet.noneAddedKey : null,
            style: typography.caption13.copyWith(color: colors.mu),
          ),
        ),
        if (music != null)
          OsdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                OsdListRow(
                  key: MusicRow.keepSoundKey,
                  title: Strings.movieMusicKeepClipSound,
                  subtitle: music.keepClipSound
                      ? null
                      : Strings.movieMusicKeepClipSoundOff,
                  trailing: OsdRowTrailing.custom(
                    OsdSwitch(value: music.keepClipSound, interactive: false),
                  ),
                  toggled: music.keepClipSound,
                  haptic: OsdHaptic.selection,
                  onTap: () => context
                      .read<CreateMovieCubit>()
                      .setKeepClipSound(keep: !music.keepClipSound),
                ),
                const OsdDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: OsdSpace.s8,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            Strings.movieMusicVolume,
                            style: typography.rowTitle.copyWith(
                              color: colors.tx,
                            ),
                          ),
                          Text(
                            MusicRow.volumeLabel(music.volume),
                            style: typography.body14.copyWith(color: colors.mu),
                          ),
                        ],
                      ),
                      OsdSlider(
                        key: MusicRow.volumeKey,
                        value: music.volume * 100,
                        min: 0,
                        max: 100,
                        divisions: MusicSheet.volumeDivisions,
                        semanticsLabel: Strings.movieMusicVolume,
                        semanticsValue: (double percent) =>
                            MusicRow.volumeLabel(percent / 100),
                        onChanged: (double percent) => context
                            .read<CreateMovieCubit>()
                            .setMusicVolume(percent / 100),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
