import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/general_tab.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/location_tab.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/subtitles_tab.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_segmented_tabs.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// The editor's General, Location and Subtitles tabs and what they show.
///
/// Another tab's content fades in and slides from the side it comes from
/// as the old one leaves the other way (mirrored in RTL); under reduced
/// motion it is a crossfade. The first visit to Subtitles without a
/// subtitle opens the subtitle sheet once the tab is in.
class EditClipTabs extends StatefulWidget {
  const EditClipTabs({super.key});

  /// How far the content slides.
  static const double slide = 8;

  @override
  State<EditClipTabs> createState() => _EditClipTabsState();
}

class _EditClipTabsState extends State<EditClipTabs> {
  static const int _subtitles = 2;

  /// The tabs' visual container (`OsdSegmentedTabs` draws it in a 48 hit
  /// area): the gaps around the tabs are measured to it.
  static const double _container = 46;
  static const double _inset = (OsdSizes.minTap - _container) / 2;

  int _index = 0;

  /// 1 when the last move went to a later tab, -1 to an earlier one.
  int _travel = 1;

  /// Whether Subtitles already offered its sheet (once per editor).
  bool _offeredSubtitles = false;
  Timer? _openSubtitles;

  @override
  void dispose() {
    _openSubtitles?.cancel();
    super.dispose();
  }

  void _select(int index) {
    _openSubtitles?.cancel();
    setState(() {
      _travel = index > _index ? 1 : -1;
      _index = index;
    });
    if (index != _subtitles || _offeredSubtitles) return;
    if (context.read<EditClipCubit>().state.draft.subtitles.isNotEmpty) return;
    _offeredSubtitles = true;
    _openSubtitles = Timer(OsdMotion.d(context, OsdMotion.standard), () {
      if (!mounted || _index != _subtitles) return;
      unawaited(SubtitlesTab.edit(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final bool reduced = OsdMotion.reduced(context);
    final double travel =
        _travel *
        (Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14 - _inset, 16, 0),
          child: OsdSegmentedTabs(
            segments: <OsdSegment>[
              OsdSegment(
                icon: OsdIcons.tune,
                accent: colors.co,
                label: Strings.saveVideoTabOne,
              ),
              OsdSegment(
                icon: OsdIcons.place,
                accent: colors.purple,
                label: Strings.saveVideoTabTwo,
              ),
              OsdSegment(
                icon: OsdIcons.subtitles,
                accent: colors.yellow,
                label: Strings.saveVideoTabThree,
              ),
            ],
            index: _index,
            onChanged: _select,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12 - _inset, 16, 0),
          child: AnimatedSize(
            duration: OsdMotion.d(context, OsdMotion.standard),
            curve: OsdMotion.curve(context, OsdMotion.standardCurve),
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: OsdMotion.d(context, OsdMotion.standard),
              switchInCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
              switchOutCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
              layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[...previous, ?current],
              ),
              transitionBuilder: (Widget child, Animation<double> animation) =>
                  FadeTransition(
                    opacity: animation,
                    child: _Slide(
                      animation: animation,
                      travel: reduced ? 0 : travel,
                      child: child,
                    ),
                  ),
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: switch (_index) {
                  0 => const GeneralTab(),
                  1 => const LocationTab(),
                  _ => const SubtitlesTab(),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Moves a tab's content [EditClipTabs.slide] px along the way the tabs
/// went: in from the end, out to the start ([travel] 1), or the other way
/// round (-1).
class _Slide extends AnimatedWidget {
  const _Slide({
    required Animation<double> animation,
    required this.travel,
    required this.child,
  }) : super(listenable: animation);

  final double travel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = listenable as Animation<double>;
    final bool leaving = animation.status == AnimationStatus.reverse;
    final double left = EditClipTabs.slide * (1 - animation.value);
    return Transform.translate(
      offset: Offset(travel * (leaving ? -left : left), 0),
      child: child,
    );
  }
}
