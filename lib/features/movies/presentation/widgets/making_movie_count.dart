import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/display_text.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The making page's count row: "12 / 25 clips" with the clips done big and the
/// rest small, wherever the language puts the number, and the percent at the
/// end, on one baseline.
class MakingMovieCount extends StatelessWidget {
  const MakingMovieCount({super.key});

  /// The semantics of the row.
  static const Key rowKey = Key('makingMovieCount.row');

  /// The clips done.
  static const Key numberKey = Key('makingMovieCount.number');

  /// The rest of the count (" / 25 clips").
  static const Key unitKey = Key('makingMovieCount.unit');

  static const Key percentKey = Key('makingMovieCount.percent');

  @override
  Widget build(BuildContext context) {
    final ({int done, int total, double progress}) job = context
        .select<MovieJobBloc, ({int done, int total, double progress})>(
          (MovieJobBloc job) => (
            done: job.state.processed,
            total: job.state.clips.length,
            progress: job.state.progress,
          ),
        );
    return _CountRow(
      done: job.done,
      total: job.total,
      progress: job.progress,
      format: MovieLabels.numberFormat(context),
      percent: MovieLabels.percent(context, job.progress),
    );
  }
}

class _CountRow extends StatefulWidget {
  const _CountRow({
    required this.done,
    required this.total,
    required this.progress,
    required this.format,
    required this.percent,
  });

  final int done;
  final int total;
  final double progress;
  final NumberFormat format;

  /// [progress] as the locale writes a percent.
  final String percent;

  @override
  State<_CountRow> createState() => _CountRowState();
}

class _CountRowState extends State<_CountRow> {
  /// The tenth of the job last announced.
  late int _tenth;

  /// What screen readers heard last.
  late String _announced;

  static int _tenthOf(double progress) => (progress * 10 + 1e-9).floor();

  @override
  void initState() {
    super.initState();
    _tenth = _tenthOf(widget.progress);
    _announced = _announcement();
  }

  String _announcement() => Strings.makingMovieProgressSemantics(
    widget.total,
    done: widget.done,
    percent: widget.percent,
    format: widget.format,
  );

  @override
  void didUpdateWidget(_CountRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int tenth = _tenthOf(widget.progress);
    // Another format is another language (MovieLabels caches one per
    // locale): say where the movie is in that language at once.
    if (tenth != _tenth ||
        widget.total != oldWidget.total ||
        !identical(widget.format, oldWidget.format)) {
      _tenth = tenth;
      _announced = _announcement();
    }
  }

  /// [count] as the language writes it, safe for the display font.
  String _drawn(int count) => DisplayText.safe(widget.format.format(count));

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final TextScaler display = OsdTextScale.scalerFor(
      context,
      OsdTextScaleRole.display,
    );
    final String text = DisplayText.safe(
      Strings.makingMovieOfTotal(
        widget.total,
        done: widget.done,
        format: widget.format,
      ),
    );
    final String number = _drawn(widget.done);
    final int at = _numberAt(text, number);
    final TextStyle small = typography.displayUnit.copyWith(color: colors.mu);
    final TextStyle big = typography.title30.copyWith(color: colors.tx);
    return Semantics(
      key: MakingMovieCount.rowKey,
      container: true,
      liveRegion: true,
      label: _announced,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  if (at > 0) _Unit(text.substring(0, at), style: small),
                  _TickingNumber(
                    value: widget.done,
                    widest: _drawn(widget.total),
                    format: _drawn,
                    style: big,
                    textScaler: display,
                  ),
                  Flexible(
                    child: _Unit(
                      at < 0 ? text : text.substring(at + number.length),
                      textKey: MakingMovieCount.unitKey,
                      style: small,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              widget.percent,
              key: MakingMovieCount.percentKey,
              maxLines: 1,
              style: typography.titleSmall.copyWith(
                color: colors.coInk,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where [number] stands on its own in [text] ("2" in "2 / 25", not in
/// "25"); -1 when the translation writes it otherwise.
int _numberAt(String text, String number) {
  bool isDigit(int at) =>
      at >= 0 && at < text.length && '0123456789'.contains(text[at]);
  for (
    int at = text.indexOf(number);
    at >= 0;
    at = text.indexOf(number, at + 1)
  ) {
    if (!isDigit(at - 1) && !isDigit(at + number.length)) return at;
  }
  return -1;
}

/// The count's small part.
class _Unit extends StatelessWidget {
  const _Unit(this.text, {required this.style, this.textKey});

  final String text;
  final TextStyle style;
  final Key? textKey;

  @override
  Widget build(BuildContext context) => Text(
    text,
    key: textKey,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textScaler: OsdTextScale.scalerFor(context, OsdTextScaleRole.display),
    style: style,
  );
}

/// The clips done, ticking up as they change (`countTick`), or jumping
/// when the last change is less than a tick ago; as wide as [widest].
class _TickingNumber extends StatefulWidget {
  const _TickingNumber({
    required this.value,
    required this.widest,
    required this.format,
    required this.style,
    required this.textScaler,
  });

  final int value;

  /// The widest the number gets (the total).
  final String widest;

  /// [value] as drawn.
  final String Function(int value) format;
  final TextStyle style;
  final TextScaler textScaler;

  @override
  State<_TickingNumber> createState() => _TickingNumberState();
}

class _TickingNumberState extends State<_TickingNumber> {
  Duration? _changedAt;
  bool _tick = true;

  @override
  void didUpdateWidget(_TickingNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    final Duration now = SchedulerBinding.instance.currentFrameTimeStamp;
    final Duration? last = _changedAt;
    _tick = last == null || now - last >= OsdMotion.countTick;
    _changedAt = now;
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.format(widget.value);
    final double slide =
        OsdMotion.countTickSlide / ((widget.style.fontSize ?? 30) * 1.1);
    return Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: <Widget>[
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: _text(widget.widest),
        ),
        AnimatedSwitcher(
          duration: _tick && !OsdMotion.reduced(context)
              ? OsdMotion.countTick
              : Duration.zero,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final bool incoming = child.key == ValueKey<String>(text);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, incoming ? slide : -slide),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
            alignment: AlignmentDirectional.bottomStart,
            children: <Widget>[...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey<String>(text),
            child: _text(text, key: MakingMovieCount.numberKey),
          ),
        ),
      ],
    );
  }

  Text _text(String data, {Key? key}) => Text(
    data,
    key: key,
    maxLines: 1,
    softWrap: false,
    textScaler: widget.textScaler,
    style: widget.style,
  );
}
