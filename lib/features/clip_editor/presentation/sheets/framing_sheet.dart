import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length_format.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_render_plan.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/framing_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/frame_viewport.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/option_tile.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_slider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_forced_dark.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The framing sheet: the clip's canvas with
/// the source on it. A pinch zooms around the fingers, from "fit" (the
/// whole picture, with bars) to a close crop; a drag moves it; a double
/// tap toggles fit and cover. The zoom slider, with its fit, cover and
/// lossless marks, and the buttons do everything the gestures do.
/// "Fill" paints the bars black or with a blurred copy of the picture,
/// remembered per canvas. Reset frames the source by default again.
///
/// A change applies when the fingers lift, to the preview behind the
/// sheet too (no cancel; every way out keeps it). A video plays on in the
/// frame, from the editor's player. Photos get the same sheet.
class FramingSheet extends StatefulWidget {
  const FramingSheet({super.key, required this.format});

  /// The canvas, which takes the drags, pinches and double taps.
  static const Key frameKey = Key('framingSheet.frame');

  static const Key sliderKey = Key('framingSheet.zoom');

  static const Key fitKey = Key('framingSheet.fit');

  static const Key coverKey = Key('framingSheet.cover');

  static const Key losslessKey = Key('framingSheet.lossless');

  static const Key blackKey = Key('framingSheet.black');

  static const Key blurKey = Key('framingSheet.blur');

  static const Key resetKey = Key('framingSheet.reset');

  static const Key doneKey = Key('framingSheet.done');

  /// The tallest the frame gets (a portrait canvas).
  static const double _maxFrameHeight = 300;

  /// The format of the profile the clip goes to: its canvas.
  final ClipFormat format;

  /// Opens the sheet over the clip editor of [context], whose source's
  /// shape is known.
  static Future<void> show(BuildContext context, {required ClipFormat format}) {
    final EditClipCubit editor = context.read<EditClipCubit>();
    final PlayerPool pool = context.read<PlayerPool>();
    return showOsdSheet<void>(
      context,
      title: Strings.framingSheetTitle,
      subtitle: Strings.framingHint,
      child: RepositoryProvider<PlayerPool>.value(
        value: pool,
        child: BlocProvider<EditClipCubit>.value(
          value: editor,
          child: FramingSheet(format: format),
        ),
      ),
    );
  }

  @override
  State<FramingSheet> createState() => _FramingSheetState();
}

class _FramingSheetState extends State<FramingSheet> {
  late final EditClipCubit _editor = context.read<EditClipCubit>();

  late final FramingCubit _framing = FramingCubit(
    geometry: _geometryOf(_editor.state),
    sizeKnown: _editor.state.sourceSize != null,
    initial: _editor.state.draft.frameFor(widget.format.orientation),
    defaultFill: _editor.rememberedFill(widget.format.orientation),
  );

  double get _canvasAspectRatio => widget.format.width / widget.format.height;

  /// The source on the canvas: with its real pixels once probed, else its
  /// shape alone.
  ClipFrameGeometry _geometryOf(EditClipState state) {
    final SourceSize? size = state.sourceSize;
    return size == null
        ? FrameViewport.geometryOf(
            aspectRatio: state.sourceAspectRatio!,
            canvasAspectRatio: _canvasAspectRatio,
          )
        : ClipFrameGeometry(
            sourceWidth: size.width,
            sourceHeight: size.height,
            canvasWidth: widget.format.width,
            canvasHeight: widget.format.height,
          );
  }

  @override
  void dispose() {
    unawaited(_framing.close());
    super.dispose();
  }

  /// Gives the editor the frame as it is now (none for the default).
  void _commit() {
    final FramingState state = _framing.state;
    _editor.frameChanged(
      state.isDefault ? null : state.frame,
      canvas: widget.format.orientation,
    );
  }

  void _run(void Function() change) {
    change();
    _commit();
  }

  void _fill(FrameFill fill) {
    _run(() => _framing.fillChanged(fill));
    unawaited(_editor.rememberFill(fill, canvas: widget.format.orientation));
  }

  @override
  Widget build(BuildContext context) {
    final ClipLengthFormat numbers = ClipLengthFormat.of(
      Localizations.localeOf(context).toString(),
    );
    return BlocProvider<FramingCubit>.value(
      value: _framing,
      child: BlocListener<EditClipCubit, EditClipState>(
        listenWhen: (EditClipState before, EditClipState after) =>
            before.sourceSize != after.sourceSize,
        listener: (BuildContext context, EditClipState state) =>
            _framing.geometryChanged(
              _geometryOf(state),
              sizeKnown: state.sourceSize != null,
            ),
        child: BlocBuilder<FramingCubit, FramingState>(
          builder: (BuildContext context, FramingState state) {
            final ClipFrameGeometry geometry = state.geometry;
            final bool fitIsCover =
                (geometry.coverScale - geometry.fitScale).abs() <=
                FramingCubit.sameScale;
            String zoomOf(double scale) => Strings.saveVideoCropZoom(
              zoom: numbers.secondsFormat.format(scale / geometry.coverScale),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: OsdSpace.sheetGap,
              children: <Widget>[
                OsdForcedDark(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: OsdMedia.letterbox,
                      borderRadius: BorderRadius.circular(OsdRadius.r16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(OsdSpace.s12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        spacing: OsdSpace.s12,
                        children: <Widget>[
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: FramingSheet._maxFrameHeight,
                              ),
                              child: AspectRatio(
                                aspectRatio: _canvasAspectRatio,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    OsdRadius.r10,
                                  ),
                                  child: _FrameGestures(
                                    key: FramingSheet.frameKey,
                                    onMoved: _framing.dragged,
                                    onPinched: _framing.pinched,
                                    onDoubleTap: () =>
                                        _run(_framing.doubleTapped),
                                    onEnded: _commit,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: <Widget>[
                                        FrameViewport(
                                          aspectRatio:
                                              _editor.state.sourceAspectRatio!,
                                          canvasAspectRatio: _canvasAspectRatio,
                                          frame: state.frame,
                                          blurred: _FrameSource(
                                            source: _editor.state.args.source,
                                          ),
                                          child: _FrameSource(
                                            source: _editor.state.args.source,
                                          ),
                                        ),
                                        const CustomPaint(
                                          painter: _ThirdsPainter(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          OsdSlider(
                            key: FramingSheet.sliderKey,
                            value: state.frame.scale,
                            min: geometry.fitScale,
                            max: geometry.maxZoom,
                            marks: <OsdSliderMark>[
                              OsdSliderMark(
                                value: geometry.fitScale,
                                label: fitIsCover
                                    ? Strings.framingCover
                                    : Strings.framingFit,
                              ),
                              if (!fitIsCover)
                                OsdSliderMark(
                                  value: geometry.coverScale,
                                  label: Strings.framingCover,
                                ),
                              if (state.showsLossless)
                                OsdSliderMark(
                                  value: geometry.losslessScale,
                                  label: Strings.framingLossless,
                                ),
                            ],
                            semanticsLabel: Strings.saveVideoCropZoomLabel,
                            semanticsValue: zoomOf,
                            onChanged: _framing.zoomTo,
                            onChangeEnd: (double scale) =>
                                _run(() => _framing.zoomTo(scale)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  spacing: OsdSpace.s8,
                  children: <Widget>[
                    Expanded(
                      child: OptionTile(
                        key: FramingSheet.fitKey,
                        label: Strings.framingFit,
                        selected: state.atFit,
                        onTap: () => _run(_framing.fit),
                      ),
                    ),
                    Expanded(
                      child: OptionTile(
                        key: FramingSheet.coverKey,
                        label: Strings.framingCover,
                        selected: state.atCover && !state.atFit,
                        onTap: () => _run(_framing.cover),
                      ),
                    ),
                    if (state.showsLossless)
                      Expanded(
                        child: OptionTile(
                          key: FramingSheet.losslessKey,
                          label: Strings.framingLossless,
                          selected: state.lossless && !state.atFit,
                          onTap: () => _run(_framing.losslessZoom),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: OsdSpace.s8,
                  children: <Widget>[
                    SectionLabel.soft(label: Strings.framingFill),
                    Row(
                      spacing: OsdSpace.s8,
                      children: <Widget>[
                        Expanded(
                          child: OptionTile(
                            key: FramingSheet.blackKey,
                            label: Strings.framingFillBlack,
                            selected: state.frame.fill == FrameFill.black,
                            onTap: () => _fill(FrameFill.black),
                          ),
                        ),
                        Expanded(
                          child: OptionTile(
                            key: FramingSheet.blurKey,
                            label: Strings.framingFillBlur,
                            selected: state.frame.fill == FrameFill.blur,
                            onTap: () => _fill(FrameFill.blur),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  spacing: OsdSpace.s8,
                  children: <Widget>[
                    Expanded(
                      child: NeutralButton(
                        key: FramingSheet.resetKey,
                        label: Strings.reset,
                        onPressed: state.isDefault
                            ? null
                            : () => _run(_framing.reset),
                      ),
                    ),
                    Expanded(
                      child: NeutralButton(
                        key: FramingSheet.doneKey,
                        label: Strings.done,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The whole source, at any size: the photo, or the video from the editor's
/// player (another view of the one the preview shows).
class _FrameSource extends StatelessWidget {
  const _FrameSource({required this.source});

  final ClipSource source;

  @override
  Widget build(BuildContext context) => switch (source) {
    PhotoSource(:final String path) => Image(
      image: FrameViewport.photo(path),
      fit: BoxFit.fill,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    ),
    VideoSource(:final String path) => ValueListenableBuilder<ShownPlayer?>(
      valueListenable: context.read<PlayerPool>().shown,
      builder: (BuildContext context, ShownPlayer? shown, _) {
        final PlayerHandle? handle = shown?.path == path ? shown?.handle : null;
        return handle?.buildView() ?? const SizedBox.shrink();
      },
    ),
  };
}

/// The frame's drags, pinches and double taps, in fractions of the frame.
///
/// It takes every touch on the frame at once (an eager recogniser), so
/// neither a drag down pulls the sheet nor a drag scrolls it; the pointers
/// are then read as they are: their middle moves the source, and with two
/// or more their spread zooms it around that middle. Two short, still taps
/// within [doubleTapWithin] of each other are a double tap.
class _FrameGestures extends StatefulWidget {
  const _FrameGestures({
    super.key,
    required this.onMoved,
    required this.onPinched,
    required this.onDoubleTap,
    required this.onEnded,
    required this.child,
  });

  /// How long after a tap a second one still makes a double tap.
  static const Duration doubleTapWithin = Duration(milliseconds: 300);

  /// How long a finger may stay down, and how far it may move, to count
  /// as a tap.
  static const Duration tapWithin = Duration(milliseconds: 250);
  static const double tapSlop = 12;

  /// The fingers' middle moved by this much of the frame.
  final ValueChanged<Offset> onMoved;

  /// The fingers spread (above 1) or closed (below 1) by this ratio, around
  /// this point of the frame.
  final void Function(double ratio, Offset focal) onPinched;

  final VoidCallback onDoubleTap;

  /// The last finger lifted.
  final VoidCallback onEnded;

  final Widget child;

  @override
  State<_FrameGestures> createState() => _FrameGesturesState();
}

class _FrameGesturesState extends State<_FrameGestures> {
  /// The fingers on the frame and where they are.
  final Map<int, Offset> _pointers = <int, Offset>{};

  /// Where and when each finger went down, for the taps.
  final Map<int, (Offset, Duration)> _downs = <int, (Offset, Duration)>{};

  /// Whether more than one finger was down since the last lift: no tap.
  bool _multi = false;

  /// When the last tap ended (the pointer event's clock).
  Duration? _lastTapAt;

  Offset get _middle =>
      _pointers.values.reduce((Offset a, Offset b) => a + b) /
      _pointers.length.toDouble();

  /// How far the fingers are from their middle, on average; 0 for one.
  double get _spread {
    if (_pointers.length < 2) return 0;
    final Offset middle = _middle;
    double sum = 0;
    for (final Offset pointer in _pointers.values) {
      sum += (pointer - middle).distance;
    }
    return sum / _pointers.length;
  }

  void _down(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    _downs[event.pointer] = (event.localPosition, event.timeStamp);
    if (_pointers.length > 1) _multi = true;
  }

  void _move(PointerMoveEvent event) {
    final Size? size = context.size;
    if (!_pointers.containsKey(event.pointer) || size == null || size.isEmpty) {
      return;
    }
    final Offset middleBefore = _middle;
    final double spreadBefore = _spread;
    _pointers[event.pointer] = event.localPosition;
    final Offset middle = _middle;
    final double spread = _spread;
    final Offset by = middle - middleBefore;
    if (by != Offset.zero) {
      widget.onMoved(Offset(by.dx / size.width, by.dy / size.height));
    }
    if (spreadBefore > 0 && spread > 0 && spread != spreadBefore) {
      widget.onPinched(
        spread / spreadBefore,
        Offset(middle.dx / size.width, middle.dy / size.height),
      );
    }
  }

  void _up(PointerEvent event) {
    final Offset? at = _pointers.remove(event.pointer);
    final (Offset, Duration)? down = _downs.remove(event.pointer);
    if (at == null) return;
    if (_pointers.isNotEmpty) return;
    final bool tap =
        !_multi &&
        down != null &&
        event is PointerUpEvent &&
        (event.localPosition - down.$1).distance <= _FrameGestures.tapSlop &&
        event.timeStamp - down.$2 <= _FrameGestures.tapWithin;
    _multi = false;
    if (tap) {
      final Duration? last = _lastTapAt;
      if (last != null &&
          event.timeStamp - last <= _FrameGestures.doubleTapWithin) {
        _lastTapAt = null;
        widget.onDoubleTap();
        return;
      }
      _lastTapAt = event.timeStamp;
    } else {
      _lastTapAt = null;
    }
    widget.onEnded();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        EagerGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
              EagerGestureRecognizer.new,
              (EagerGestureRecognizer recognizer) {},
            ),
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: widget.child,
      ),
    ),
  );
}

/// The rule of thirds over the frame: two lines each way.
class _ThirdsPainter extends CustomPainter {
  const _ThirdsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = OsdMedia.onMediaDotInactive
      ..strokeWidth = 1;
    for (int third = 1; third < 3; third++) {
      final double x = size.width * third / 3;
      final double y = size.height * third / 3;
      canvas
        ..drawLine(Offset(x, 0), Offset(x, size.height), line)
        ..drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_ThirdsPainter oldDelegate) => false;
}
