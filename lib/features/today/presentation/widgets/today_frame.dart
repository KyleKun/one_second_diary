import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/policy/date_stamp.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_state.dart';
import 'package:one_second_diary/features/today/presentation/today_motion.dart';
import 'package:one_second_diary/features/today/presentation/today_stamp.dart';
import 'package:one_second_diary/features/today/presentation/widgets/held_while_hidden.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_clip_carousel.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/progress/slow_load_bar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/clip_placeholder.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// What Today's frame shows, crossfading between:
/// - while the diary loads: a quiet frame, and after a delay a thin
///   loading bar at its bottom;
/// - an empty day: the dashed frame, previewing the date stamp in the
///   user's format;
/// - a day with clips: the clips, one in the frame or several in a pager,
///   each at its poster from the thumbnail cache.
///
/// The day's first clip arriving fades the dashed frame out while the clip
/// fades in, and a clip new to the day lands its Saved badge; Undo plays
/// it back. A change made while Today is hidden plays once Today shows
/// ([HeldWhileHidden]).
///
/// Its smallest size is the frame's (`ClipSlot`): the frames take it, the
/// clips the stage's width and the room of their page dots. It is as tall
/// as what it shows.
class TodayFrame extends StatelessWidget {
  const TodayFrame({super.key, required this.onOpen});

  /// Opens a clip in the viewer (a long press on the clip in view).
  final ValueChanged<ClipRef> onOpen;

  static const Key loadingKey = Key('todayFrame.loading');

  @override
  Widget build(BuildContext context) {
    final _Frame frame = context.select(
      (TodayCubit cubit) => _frameOf(cubit.state),
    );
    return HeldWhileHidden<_Frame>(
      value: frame,
      builder: (BuildContext context, _Frame shown) => _FrameView(
        frame: shown,
        onShow: context.read<TodayCubit>().showClip,
        onOpen: onOpen,
      ),
    );
  }
}

/// The frame shown, and the clips that just arrived in it.
class _FrameView extends StatefulWidget {
  const _FrameView({
    required this.frame,
    required this.onShow,
    required this.onOpen,
  });

  final _Frame frame;
  final ValueChanged<ClipRef> onShow;
  final ValueChanged<ClipRef> onOpen;

  @override
  State<_FrameView> createState() => _FrameViewState();
}

class _FrameViewState extends State<_FrameView> {
  /// The clips new to the day since the frame last showed it: their badge
  /// lands.
  Set<ClipRef> _arrived = const <ClipRef>{};

  @override
  void didUpdateWidget(_FrameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final _Frame before = oldWidget.frame;
    final _Frame now = widget.frame;
    final bool sameDay =
        !before.loading &&
        !now.loading &&
        before.day == now.day &&
        before.profile == now.profile;
    _arrived = sameDay
        ? now.clips.toSet().difference(before.clips.toSet())
        : const <ClipRef>{};
  }

  @override
  Widget build(BuildContext context) {
    final _Frame frame = widget.frame;
    final bool reduced = OsdMotion.reduced(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.smallest;
        final ClipRef? visible = frame.visible;
        final Widget child = frame.loading
            ? _Framed(
                size: size,
                child: const _LoadingFrame(key: TodayFrame.loadingKey),
              )
            : visible == null
            ? _Framed(
                key: const ValueKey<String>('todayFrame.empty'),
                size: size,
                child: _EmptyFrame(day: frame.day, format: frame.format!),
              )
            : TodayClipCarousel(
                // Another profile's clips crossfade in, in their own pager.
                key: ValueKey<ProfileKey>(frame.profile),
                clips: frame.clips,
                visible: visible,
                frame: size,
                orientation: frame.orientation,
                landing: _arrived,
                onShow: widget.onShow,
                onOpen: widget.onOpen,
              );
        return SizedBox(
          width: constraints.maxWidth,
          child: AnimatedSwitcher(
            duration: OsdMotion.d(context, TodayMotion.clipsIn),
            reverseDuration: OsdMotion.d(context, OsdMotion.fast),
            switchInCurve: OsdMotion.curve(context, TodayMotion.clipsInCurve),
            switchOutCurve: OsdMotion.curve(context, OsdMotion.fastCurve),
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(
                  opacity: animation,
                  child: child is TodayClipCarousel && !reduced
                      ? ScaleTransition(
                          scale: animation.drive(
                            Tween<double>(
                              begin: TodayMotion.clipsInScale,
                              end: 1,
                            ),
                          ),
                          alignment: Alignment.topCenter,
                          child: child,
                        )
                      : child,
                ),
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[...previous, ?current],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// [child] at the frame's [size].
class _Framed extends StatelessWidget {
  const _Framed({super.key, required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox.fromSize(size: size, child: child);
}

/// What the frame depends on, compared by value (the clips too), so a
/// change elsewhere in the state never rebuilds it.
final class _Frame extends Equatable {
  const _Frame({
    required this.loading,
    required this.profile,
    required this.clips,
    required this.visible,
    required this.day,
    required this.format,
    required this.orientation,
  });

  final bool loading;
  final ProfileKey profile;
  final List<ClipRef> clips;
  final ClipRef? visible;
  final LocalDay day;

  /// The date stamp's format, for the empty frame only: a new format never
  /// rebuilds the day's clips.
  final StampFormat? format;
  final VideoOrientation orientation;

  @override
  List<Object?> get props => <Object?>[
    loading,
    profile,
    clips,
    visible,
    day,
    format,
    orientation,
  ];
}

_Frame _frameOf(TodayState state) => _Frame(
  loading: state.status == TodayStatus.loading,
  profile: state.profile.key,
  clips: state.clips,
  visible: state.visibleClip,
  day: state.day,
  format: state.clips.isEmpty ? state.stampFormat : null,
  orientation: state.profile.orientation,
);

/// The frame while the diary loads: no spinner, a dimmed shape, and a
/// thin bar once it has taken longer than [TodayMotion.slowLoad].
class _LoadingFrame extends StatelessWidget {
  const _LoadingFrame({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.c2.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(OsdRadius.r20),
    ),
    child: OsdLoadingDelay(
      loading: true,
      delay: TodayMotion.slowLoad,
      builder: (BuildContext context, bool slow) => slow
          ? const Padding(
              padding: EdgeInsets.fromLTRB(
                OsdSpace.s20,
                0,
                OsdSpace.s20,
                OsdSpace.s20,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SlowLoadBar(),
              ),
            )
          : const SizedBox.expand(),
    ),
  );
}

/// The dashed frame of an empty day, with the date stamp as the video
/// will burn it ([TodayStamp]), formatted once per day and locale.
class _EmptyFrame extends StatefulWidget {
  const _EmptyFrame({required this.day, required this.format});

  final LocalDay day;
  final StampFormat format;

  @override
  State<_EmptyFrame> createState() => _EmptyFrameState();
}

class _EmptyFrameState extends State<_EmptyFrame> {
  String? _locale;
  late String _stamp;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String locale = TodayStamp.locale(context);
    if (locale != _locale) {
      _locale = locale;
      _format();
    }
  }

  @override
  void didUpdateWidget(_EmptyFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day || oldWidget.format != widget.format) {
      _format();
    }
  }

  void _format() => _stamp = DateStamp.text(
    widget.day,
    format: widget.format,
    locale: _locale!,
  );

  @override
  Widget build(BuildContext context) => ClipPlaceholder(
    stampText: _stamp,
    semanticsLabel: Strings.noVideoRecorded,
  );
}
