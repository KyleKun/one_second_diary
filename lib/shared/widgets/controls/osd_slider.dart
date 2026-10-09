import 'dart:async';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';
import 'package:one_second_diary/theme/osd_camera.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A labelled position under an [OsdSlider].
@immutable
class OsdSliderMark {
  const OsdSliderMark({required this.value, required this.label});

  final double value;

  final String label;
}

/// The camera's clip-length slider (forced dark).
///
/// At the ends the thumb overhangs the track by half its width. The touch
/// strip is taller than the row and takes no layout (put the slider straight
/// in a larger parent, such as the card's column, so touches just above it
/// arrive).
///
/// Values snap to whole [divisions]. Drags and taps report [onChanged];
/// [onChangeEnd] fires on release. [marks] sit below at their value
/// fractions (the ends aligned to the track ends). Arrow keys step when
/// focused; screen readers get a slider with increase and decrease. RTL
/// mirrors it.
class OsdSlider extends StatefulWidget {
  const OsdSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    this.marks = const <OsdSliderMark>[],
    required this.semanticsLabel,
    this.semanticsValue,
  }) : assert(max > min, 'max must be above min');

  /// The full-width inactive track.
  static const Key trackKey = Key('osdSlider.track');

  /// The part of the track from the start to the thumb.
  static const Key activeTrackKey = Key('osdSlider.activeTrack');

  static const Key thumbKey = Key('osdSlider.thumb');

  /// The row that takes touches.
  static const Key touchKey = Key('osdSlider.touch');

  static const Key focusRingKey = Key('osdSlider.focusRing');

  final double value;

  final double min;

  final double max;

  /// The number of steps between [min] and [max], if values snap.
  final int? divisions;

  /// Called with each new value while dragging.
  final ValueChanged<double> onChanged;

  /// Called with the final value when a drag or tap ends.
  final ValueChanged<double>? onChangeEnd;

  /// Labels under the track.
  final List<OsdSliderMark> marks;

  final String semanticsLabel;

  /// How a value is read out ("2 seconds"); a locale number by default.
  final String Function(double value)? semanticsValue;

  @override
  State<OsdSlider> createState() => _OsdSliderState();
}

class _OsdSliderState extends State<OsdSlider> {
  static const double _row = 24;
  static const double _trackHeight = 6;
  static const double _thumb = 22;

  double? _dragValue;
  bool _focused = false;

  double get _range => widget.max - widget.min;

  double get _step {
    final divisions = widget.divisions;
    return divisions == null ? _range / 10 : _range / divisions;
  }

  double _fraction(double value) =>
      ((value - widget.min) / _range).clamp(0, 1).toDouble();

  double _snap(double value) {
    final clamped = value.clamp(widget.min, widget.max).toDouble();
    if (widget.divisions == null) return clamped;
    final steps = ((clamped - widget.min) / _step).round();
    return (widget.min + steps * _step).clamp(widget.min, widget.max);
  }

  double _valueAt(double dx, double width) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final fraction = ((rtl ? width - dx : dx) / width).clamp(0, 1);
    return _snap(widget.min + fraction * _range);
  }

  void _set(double value) {
    final previous = _dragValue ?? widget.value;
    _dragValue = value;
    if (value == previous) return;
    unawaited(OsdHaptic.selection.play());
    widget.onChanged(value);
  }

  void _end() {
    final value = _dragValue;
    _dragValue = null;
    if (value != null) widget.onChangeEnd?.call(value);
  }

  void _stepBy(int steps) {
    final value = _snap(widget.value + steps * _step);
    if (value == widget.value) return;
    unawaited(OsdHaptic.selection.play());
    widget.onChanged(value);
    widget.onChangeEnd?.call(value);
  }

  String _read(double value) {
    final read = widget.semanticsValue;
    if (read != null) return read(value);
    return LocaleFormats.of(context).numbers.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final value = widget.value;
    final increased = _snap(value + _step);
    final decreased = _snap(value - _step);
    final row = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final x = _fraction(value) * width;
        return GestureDetector(
          key: OsdSlider.touchKey,
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: (details) =>
              _set(_valueAt(details.localPosition.dx, width)),
          onHorizontalDragUpdate: (details) =>
              _set(_valueAt(details.localPosition.dx, width)),
          onHorizontalDragEnd: (_) => _end(),
          onHorizontalDragCancel: _end,
          onTapUp: (details) {
            _set(_valueAt(details.localPosition.dx, width));
            _end();
          },
          child: SizedBox(
            height: _row,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  top: (_row - _trackHeight) / 2,
                  height: _trackHeight,
                  child: DecoratedBox(
                    key: OsdSlider.trackKey,
                    decoration: BoxDecoration(
                      color: OsdCamera.sliderTrackOff,
                      borderRadius: BorderRadius.circular(_trackHeight / 2),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  top: (_row - _trackHeight) / 2,
                  width: x,
                  height: _trackHeight,
                  child: DecoratedBox(
                    key: OsdSlider.activeTrackKey,
                    decoration: BoxDecoration(
                      color: colors.tx,
                      borderRadius: BorderRadius.circular(_trackHeight / 2),
                    ),
                  ),
                ),
                if (_focused)
                  PositionedDirectional(
                    start: x - _thumb / 2 - 5,
                    top: (_row - _thumb) / 2 - 5,
                    width: _thumb + 10,
                    height: _thumb + 10,
                    child: DecoratedBox(
                      key: OsdSlider.focusRingKey,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.tx, width: 2),
                      ),
                    ),
                  ),
                PositionedDirectional(
                  start: x - _thumb / 2,
                  top: (_row - _thumb) / 2,
                  width: _thumb,
                  height: _thumb,
                  child: const DecoratedBox(
                    key: OsdSlider.thumbKey,
                    decoration: BoxDecoration(
                      color: OsdCamera.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    // The row's touch strip reaches past it above and below; the outer slop
    // lets it through the column's top edge.
    return OsdHitSlop(
      slop: const EdgeInsets.symmetric(vertical: (OsdSizes.minTap - _row) / 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: <Widget>[
          OsdHitSlop(
            slop: const EdgeInsets.symmetric(
              vertical: (OsdSizes.minTap - _row) / 2,
            ),
            child: FocusableActionDetector(
              onShowFocusHighlight: (value) => setState(() => _focused = value),
              shortcuts: <ShortcutActivator, Intent>{
                const SingleActivator(LogicalKeyboardKey.arrowRight):
                    _StepIntent(rtl ? -1 : 1),
                const SingleActivator(LogicalKeyboardKey.arrowLeft):
                    _StepIntent(rtl ? 1 : -1),
                const SingleActivator(LogicalKeyboardKey.arrowUp):
                    const _StepIntent(1),
                const SingleActivator(LogicalKeyboardKey.arrowDown):
                    const _StepIntent(-1),
              },
              actions: <Type, Action<Intent>>{
                _StepIntent: CallbackAction<_StepIntent>(
                  onInvoke: (intent) {
                    _stepBy(intent.steps);
                    return null;
                  },
                ),
              },
              child: Semantics(
                slider: true,
                label: widget.semanticsLabel,
                value: _read(value),
                increasedValue: _read(increased),
                decreasedValue: _read(decreased),
                textDirection: Directionality.of(context),
                onIncrease: increased == value ? null : () => _stepBy(1),
                onDecrease: decreased == value ? null : () => _stepBy(-1),
                child: row,
              ),
            ),
          ),
          if (widget.marks.isNotEmpty)
            _Marks(
              marks: widget.marks,
              fraction: _fraction,
              style: context.typography.caption.copyWith(color: colors.mu),
            ),
        ],
      ),
    );
  }
}

class _StepIntent extends Intent {
  const _StepIntent(this.steps);

  final int steps;
}

class _Marks extends StatelessWidget {
  const _Marks({
    required this.marks,
    required this.fraction,
    required this.style,
  });

  final List<OsdSliderMark> marks;
  final double Function(double value) fraction;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // Gives the row the height of one line of marks.
              Opacity(opacity: 0, child: Text(' ', maxLines: 1, style: style)),
              for (final mark in marks)
                switch (fraction(mark.value)) {
                  <= 0 => PositionedDirectional(
                    start: 0,
                    child: Text(mark.label, maxLines: 1, style: style),
                  ),
                  >= 1 => PositionedDirectional(
                    end: 0,
                    child: Text(mark.label, maxLines: 1, style: style),
                  ),
                  final at => PositionedDirectional(
                    start: at * width,
                    child: FractionalTranslation(
                      translation: Offset(
                        Directionality.of(context) == TextDirection.rtl
                            ? .5
                            : -.5,
                        0,
                      ),
                      child: Text(mark.label, maxLines: 1, style: style),
                    ),
                  ),
                },
            ],
          ),
        );
      },
    ),
  );
}
