import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/domain/memories_feed.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/memories_month_header.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/memory_card.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/empty_state.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Memories: the whole diary, newest first, one card per recorded day
/// ([MemoryCard]) under its month's header ([MemoriesMonthHeader]), then
/// "That's the very first second".
///
/// - One lazy list over the [MemoriesFeed] (a builder, the default cache
///   extent): however long the diary, only the rows on screen are built and
///   ask for thumbnails, and cards far behind are let go.
/// - The header of the month scrolled through stays on top (a
///   `DiaryMonthHeader.feed` with its hairline), pushed up by the next
///   month's header: an overlay that follows the rows' positions, so the
///   list itself never keeps a card of every month alive.
/// - The first cards rise in once (`OsdMotion.entrance`, [entrance]).
/// - Back from the viewer, the card of the day it showed last scrolls into
///   view.
/// - A diary without clips shows the empty state with "Record today"; one
///   that could not be read says so, with "Try again".
/// - Under the Diary's filter the feed is of the clips it keeps; when none
///   matches, "No videos match" with Clear filter.
/// - On a tablet the cards go two a row, kept to the middle.
class MemoriesView extends StatefulWidget {
  const MemoriesView({
    super.key,
    required this.controller,
    this.entrance = true,
  });

  /// The feed's scroll view.
  static const Key listKey = Key('memoriesView.list');

  /// The header pinned on top.
  static const Key stickyKey = Key('memoriesView.sticky');

  /// "That's the very first second".
  static const Key endKey = Key('memoriesView.end');

  /// "No videos match" under a filter.
  static const Key noMatchesKey = Key('memoriesView.noMatches');

  /// The tab's scroll controller (a reselect scrolls it back up).
  final ScrollController controller;

  /// Whether the first cards rise in (the first time Memories shows).
  final bool entrance;

  @override
  State<MemoriesView> createState() => _MemoriesViewState();
}

/// The month on top, and how far the next month's header pushes it up.
typedef _Pinned = ({DiaryMonth month, double push});

class _MemoriesViewState extends State<MemoriesView> {
  static const double _cardGap = 14;
  static const double _tabletRowGap = 20;
  static const double _endHeight = 56;
  static const double _bottomRoom = 24;
  static const Duration _revealDuration = Duration(milliseconds: 300);

  final Set<_FeedRowState> _rows = <_FeedRowState>{};
  final ValueNotifier<_Pinned?> _pinned = ValueNotifier<_Pinned?>(null);
  final GlobalKey _viewport = GlobalKey();

  /// The scroll offset of the last layout the rows' positions come from.
  double _laidOutAt = 0;
  bool _measureScheduled = false;
  late bool _entrance = widget.entrance;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrolled);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _entrance = false;
      _measure();
    });
  }

  @override
  void didUpdateWidget(MemoriesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_scrolled);
    widget.controller.addListener(_scrolled);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrolled);
    _pinned.dispose();
    super.dispose();
  }

  /// The rows moved: the header on top follows at once (from the last layout
  /// and how far it scrolled since), and again once the frame is laid out.
  void _scrolled() {
    _pin();
    if (_measureScheduled) return;
    _measureScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      _measure();
    });
  }

  void _measure() {
    if (!mounted) return;
    final ScrollController controller = widget.controller;
    _laidOutAt = controller.hasClients ? controller.position.pixels : 0;
    _pin();
  }

  void _pin() {
    final ScrollController controller = widget.controller;
    final RenderObject? viewport = _viewport.currentContext?.findRenderObject();
    if (!controller.hasClients ||
        controller.position.pixels <= 0 ||
        viewport == null ||
        !viewport.attached) {
      _pinned.value = null;
      return;
    }
    final double shift = controller.position.pixels - _laidOutAt;
    DiaryMonth? month;
    double? headerHeight;
    double? nextHeader;
    for (final _FeedRowState row in _rows) {
      final RenderObject? box = row.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final double top =
          box.localToGlobal(Offset.zero, ancestor: viewport).dy - shift;
      final double bottom = top + box.size.height;
      if (row.widget.header) {
        headerHeight = box.size.height;
        if (top > 0 && (nextHeader == null || top < nextHeader)) {
          nextHeader = top;
        }
      }
      if (top <= 0 && bottom > 0) month = row.widget.month;
    }
    if (month == null) return;
    final double push = headerHeight != null && nextHeader != null
        ? (nextHeader - headerHeight).clamp(-headerHeight, 0)
        : 0;
    final _Pinned pinned = (month: month, push: push);
    if (_pinned.value != pinned) _pinned.value = pinned;
  }

  /// Brings [clip]'s card into view, when it is built.
  void _revealCard(ClipRef clip) {
    for (final _FeedRowState row in _rows) {
      if (!row.widget.days.contains(clip.day)) continue;
      unawaited(
        Scrollable.ensureVisible(
          row.context,
          duration: OsdMotion.d(context, _revealDuration),
          curve: OsdMotion.curve(context, OsdMotion.standardCurve),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (ClipIndex? index, bool filtered, bool unreadable) = context.select(
      (DiaryCubit cubit) => (
        cubit.state.filteredIndex,
        cubit.state.isFiltered,
        cubit.state.status == DiaryStatus.failed,
      ),
    );
    if (unreadable) {
      return Center(
        child: SingleChildScrollView(
          controller: widget.controller,
          child: EmptyState(
            icon: OsdIcons.error,
            title: Strings.storageUnavailableTitle,
            body: Strings.diaryUnreadableHint,
            action: NeutralButton(
              label: Strings.commonTryAgain,
              hug: true,
              onPressed: () =>
                  unawaited(context.read<DiaryCubit>().readAgain()),
            ),
          ),
        ),
      );
    }
    if (index == null) return const SizedBox.expand();
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= OsdSizes.tabletShortestSide ? 2 : 1;
    final double gutter = columns == 1
        ? OsdSpace.pageGutter
        : math.max(OsdSpace.pageGutter, (width - OsdSizes.mediaMaxWidth) / 2);
    final MemoriesFeed feed = MemoriesFeed.of(index, columns: columns);
    if (feed.isEmpty && filtered) {
      return Center(
        child: SingleChildScrollView(
          controller: widget.controller,
          child: EmptyState(
            key: MemoriesView.noMatchesKey,
            icon: OsdIcons.filterList,
            title: Strings.diaryFilterNoMatches,
            action: NeutralButton(
              label: Strings.diaryFilterClear,
              hug: true,
              onPressed: context.read<DiaryCubit>().clearFilter,
            ),
          ),
        ),
      );
    }
    if (feed.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          controller: widget.controller,
          child: EmptyState(
            icon: OsdIcons.autoStories,
            title: Strings.memoriesEmptyTitle,
            body: Strings.memoriesEmptyBody,
            action: PrimaryButton(
              label: Strings.memoriesEmptyCta,
              icon: OsdIcons.videocam,
              hug: true,
              onPressed: () => AppRoute.today.go(context),
            ),
          ),
        ),
      );
    }
    return Stack(
      children: <Widget>[
        KeyedSubtree(
          key: _viewport,
          child: CustomScrollView(
            key: MemoriesView.listKey,
            controller: widget.controller,
            slivers: <Widget>[
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                sliver: SliverList.builder(
                  itemCount: feed.length + 1,
                  itemBuilder: (BuildContext context, int row) =>
                      row == feed.length
                      ? const _FeedEnd()
                      : switch (feed[row]) {
                          MemoriesMonthRow(:final DiaryMonth month) => _FeedRow(
                            key: ValueKey<DiaryMonth>(month),
                            rows: _rows,
                            month: month,
                            header: true,
                            child: MemoriesMonthHeader(month: month),
                          ),
                          MemoriesDayRow(:final List<LocalDay> days) =>
                            _FeedRow(
                              key: ValueKey<(String, LocalDay)>((
                                'memoriesRow',
                                days.first,
                              )),
                              rows: _rows,
                              month: feed.monthAt(row),
                              days: days,
                              entranceDelay: _entrance
                                  ? OsdMotion.entranceDelay(context, row)
                                  : null,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: columns == 1
                                      ? _cardGap
                                      : _tabletRowGap,
                                ),
                                child: columns == 1
                                    ? MemoryCard(
                                        key: MemoryCard.keyOf(days.single),
                                        day: days.single,
                                        onReturned: _revealCard,
                                      )
                                    : _CardRow(
                                        days: days,
                                        columns: columns,
                                        gap: _cardGap,
                                        onReturned: _revealCard,
                                      ),
                              ),
                            ),
                        },
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _bottomRoom + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ),
        PositionedDirectional(
          top: 0,
          start: gutter,
          end: gutter,
          child: ValueListenableBuilder<_Pinned?>(
            valueListenable: _pinned,
            builder: (BuildContext context, _Pinned? pinned, _) =>
                pinned == null
                ? const SizedBox.shrink()
                : Transform.translate(
                    offset: Offset(0, pinned.push),
                    child: ExcludeSemantics(
                      child: MemoriesMonthHeader(
                        key: MemoriesView.stickyKey,
                        month: pinned.month,
                        scrolledUnder: true,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// A row of the feed: it tells the view where it is (for the header on
/// top), and the first ones rise in.
class _FeedRow extends StatefulWidget {
  const _FeedRow({
    super.key,
    required this.rows,
    required this.month,
    required this.child,
    this.header = false,
    this.days = const <LocalDay>[],
    this.entranceDelay,
  });

  final Set<_FeedRowState> rows;
  final DiaryMonth month;
  final bool header;

  /// The days whose cards the row holds.
  final List<LocalDay> days;
  final Duration? entranceDelay;
  final Widget child;

  @override
  State<_FeedRow> createState() => _FeedRowState();
}

class _FeedRowState extends State<_FeedRow>
    with SingleTickerProviderStateMixin {
  AnimationController? _entrance;
  CurvedAnimation? _rise;

  @override
  void initState() {
    super.initState();
    widget.rows.add(this);
    final Duration? delay = widget.entranceDelay;
    if (delay == null) return;
    final Duration total = delay + OsdMotion.entrance;
    final AnimationController entrance = _entrance = AnimationController(
      vsync: this,
      duration: total,
    );
    _rise = CurvedAnimation(
      parent: entrance,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: OsdMotion.standardCurve,
      ),
    );
    unawaited(entrance.forward());
  }

  @override
  void dispose() {
    widget.rows.remove(this);
    _rise?.dispose();
    _entrance?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double>? rise = _rise;
    if (rise == null) return widget.child;
    return FadeTransition(
      opacity: rise,
      child: AnimatedBuilder(
        animation: rise,
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(0, (1 - rise.value) * OsdMotion.entranceRise),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// A row of cards side by side (tablets), the last one maybe alone.
class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.days,
    required this.columns,
    required this.gap,
    required this.onReturned,
  });

  final List<LocalDay> days;
  final int columns;
  final double gap;
  final ValueChanged<ClipRef> onReturned;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: gap,
    children: <Widget>[
      for (int column = 0; column < columns; column++)
        Expanded(
          child: column < days.length
              ? MemoryCard(
                  key: MemoryCard.keyOf(days[column]),
                  day: days[column],
                  fitWidth: true,
                  onReturned: onReturned,
                )
              : const SizedBox.shrink(),
        ),
    ],
  );
}

/// "That's the very first second", after the oldest day, in MU (FA text
/// fails AA).
class _FeedEnd extends StatelessWidget {
  const _FeedEnd();

  @override
  Widget build(BuildContext context) => SizedBox(
    key: MemoriesView.endKey,
    height: _MemoriesViewState._endHeight,
    child: Center(
      child: Text(
        Strings.memoriesEnd,
        textAlign: TextAlign.center,
        style: context.typography.caption13.copyWith(color: context.colors.mu),
      ),
    ),
  );
}
