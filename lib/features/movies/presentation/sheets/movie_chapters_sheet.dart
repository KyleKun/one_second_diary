import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_player_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The movie player's chapters (`Chapters`, tall): one row per chapter (per
/// clip) in movie order, its title and how long it runs, the one playing
/// checked.
class MovieChaptersSheet extends StatefulWidget {
  const MovieChaptersSheet({super.key});

  static const Key listKey = Key('movieChaptersSheet.list');

  /// The row of the chapter at [index] (0-based, movie order).
  static Key rowKey(int index) =>
      ValueKey<String>('movieChaptersSheet.row.$index');

  /// Opens the sheet over the whole app for the player of [context]
  /// ([MoviePlayerCubit]).
  static Future<void> show(BuildContext context, {String? subtitle}) {
    final MoviePlayerCubit cubit = context.read<MoviePlayerCubit>();
    return showOsdSheet<void>(
      context,
      title: Strings.movieChapters,
      subtitle: subtitle,
      height: OsdSheetHeight.tall,
      child: BlocProvider<MoviePlayerCubit>.value(
        value: cubit,
        child: const MovieChaptersSheet(),
      ),
    );
  }

  @override
  State<MovieChaptersSheet> createState() => _MovieChaptersSheetState();
}

class _MovieChaptersSheetState extends State<MovieChaptersSheet> {
  /// The sliver the list grows from (scroll offset 0).
  static const Key _centre = ValueKey<String>('movieChaptersSheet.centre');

  /// The row of the chapter playing when the sheet opened, kept in view.
  final GlobalKey _openedWith = GlobalKey();

  late final List<MovieChapter> _chapters = context
      .read<MoviePlayerCubit>()
      .state
      .chapters;

  late final int _opened = switch (context
      .read<MoviePlayerCubit>()
      .state
      .currentChapter) {
    null => 0,
    final MovieChapter playing => math.max(0, _chapters.indexOf(playing)),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? row = _openedWith.currentContext;
      if (row != null && row.mounted) {
        unawaited(
          Scrollable.ensureVisible(
            row,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          ),
        );
      }
    });
  }

  /// How many rows at least fill [height]: a row is never shorter than
  /// its minimum, nor than its padding around one line of its title.
  int _rowsFilling(BuildContext context, double height) {
    final TextStyle title = context.typography.rowTitle;
    final double line =
        MediaQuery.textScalerOf(context).scale(title.fontSize ?? 16) *
        (title.height ?? 1);
    final double row =
        math.max(OsdSizes.listRowHeight, OsdSpace.rowPadV * 2 + line) +
        OsdSpace.s4;
    return (height / row).floor();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      // The sliver at the viewport's centre starts at the chapter playing, so
      // it sits at the top whatever the rows' heights; near the end, enough
      // earlier chapters lead it that the sheet stays full.
      final int first = math.min(
        _opened,
        math.max(
          0,
          _chapters.length - _rowsFilling(context, constraints.maxHeight),
        ),
      );
      Widget row(int index) {
        final Widget row = Padding(
          padding: const EdgeInsets.only(bottom: OsdSpace.s4),
          child: _ChapterRow(index: index, chapter: _chapters[index]),
        );
        return index == _opened
            ? KeyedSubtree(key: _openedWith, child: row)
            : row;
      }

      return CustomScrollView(
        key: MovieChaptersSheet.listKey,
        center: _centre,
        scrollCacheExtent: ScrollCacheExtent.pixels(constraints.maxHeight),
        slivers: <Widget>[
          SliverList.builder(
            itemCount: first,
            itemBuilder: (BuildContext context, int index) =>
                row(first - 1 - index),
          ),
          SliverList.builder(
            key: _centre,
            itemCount: _chapters.length - first,
            itemBuilder: (BuildContext context, int index) =>
                row(first + index),
          ),
        ],
      );
    },
  );
}

/// One chapter: its title, how long it runs, and a check while it plays.
/// Rebuilds only when its check changes.
class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.index, required this.chapter});

  final int index;
  final MovieChapter chapter;

  @override
  Widget build(BuildContext context) {
    final bool playing = context.select<MoviePlayerCubit, bool>(
      (MoviePlayerCubit cubit) => cubit.state.currentChapter == chapter,
    );
    return OsdListRow(
      key: MovieChaptersSheet.rowKey(index),
      title: chapter.title,
      value: MovieLabels.clock(Duration(milliseconds: chapter.durationMs)),
      trailing: playing
          ? const OsdRowTrailing.check()
          : const OsdRowTrailing.none(),
      checked: playing,
      inMutuallyExclusiveGroup: true,
      onTap: () {
        context.read<MoviePlayerCubit>().seekToChapter(chapter);
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            chapter.title,
            Directionality.of(context),
          ),
        );
        Navigator.of(context).pop();
      },
    );
  }
}
