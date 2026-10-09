import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_radio_row.dart';

/// The ranges of Create movie: a card of radio rows. A tap picks the range;
/// only this card rebuilds.
class MoviePresetCard extends StatelessWidget {
  const MoviePresetCard({super.key});

  static const Key cardKey = Key('moviePresetCard.card');

  static Key rowKey(MoviePreset preset) =>
      ValueKey<String>('moviePresetCard.${preset.name}');

  @override
  Widget build(BuildContext context) {
    final MoviePreset selected = context.select<CreateMovieCubit, MoviePreset>(
      (CreateMovieCubit flow) => flow.state.preset,
    );
    return OsdCard(
      key: cardKey,
      child: Column(
        children: <Widget>[
          for (final MoviePreset preset in MoviePreset.values) ...<Widget>[
            if (preset.index > 0) const OsdDivider(),
            OsdRadioRow(
              key: rowKey(preset),
              label: MovieLabels.preset(preset),
              selected: preset == selected,
              onSelected: () =>
                  context.read<CreateMovieCubit>().choosePreset(preset),
            ),
          ],
        ],
      ),
    );
  }
}
