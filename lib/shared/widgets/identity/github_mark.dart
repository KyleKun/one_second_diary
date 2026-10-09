import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// The GitHub mark. Decorative.
///
/// It is painted from the single-path Octicons `mark-github` glyph (MIT),
/// so no SVG package is needed for one icon.
class GithubMark extends StatelessWidget {
  const GithubMark({super.key, this.size = OsdSizes.iconDefault, this.color});

  final double size;

  /// The ink; MU by default.
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: GithubMarkPainter(color: color ?? context.colors.mu),
      ),
    ),
  );
}

/// Paints the GitHub mark, scaled from its 16 × 16 design box to the canvas.
class GithubMarkPainter extends CustomPainter {
  const GithubMarkPainter({required this.color});

  final Color color;

  /// The Octicons `mark-github` 16 px path (MIT, GitHub Inc.).
  static const String _svg =
      'M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 '
      '0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-'
      '1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 '
      '2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59'
      '.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 '
      '2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 '
      '2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 '
      '1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0'
      '-4.42-3.58-8-8-8z';

  /// The mark in its 16 × 16 design box.
  static final Path markPath = _SvgPath.parse(_svg)
    ..fillType = PathFillType.evenOdd;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 16, size.height / 16)
      ..drawPath(
        markPath,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(GithubMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// A minimal SVG path-data reader: M L H V C S A Z, absolute and relative,
/// with the compact number syntax ("-.17.55", arc flags without spaces).
final class _SvgPath {
  _SvgPath(this._data);

  final String _data;
  int _at = 0;

  static Path parse(String data) => _SvgPath(data)._read();

  Path _read() {
    final path = Path();
    var current = Offset.zero;
    var start = Offset.zero;
    Offset? lastControl;
    String? command;
    while (true) {
      _skipSeparators();
      if (_at >= _data.length) break;
      final char = _data[_at];
      if (RegExp('[A-Za-z]').hasMatch(char)) {
        command = char;
        _at++;
      }
      final relative = command == command!.toLowerCase();
      Offset point(double x, double y) =>
          relative ? current + Offset(x, y) : Offset(x, y);
      switch (command.toUpperCase()) {
        case 'M':
          current = point(_number(), _number());
          start = current;
          path.moveTo(current.dx, current.dy);
          lastControl = null;
          // Further pairs after a move are line-tos.
          command = relative ? 'l' : 'L';
        case 'L':
          current = point(_number(), _number());
          path.lineTo(current.dx, current.dy);
          lastControl = null;
        case 'H':
          final x = _number();
          current = Offset(relative ? current.dx + x : x, current.dy);
          path.lineTo(current.dx, current.dy);
          lastControl = null;
        case 'V':
          final y = _number();
          current = Offset(current.dx, relative ? current.dy + y : y);
          path.lineTo(current.dx, current.dy);
          lastControl = null;
        case 'C':
          final c1 = point(_number(), _number());
          final c2 = point(_number(), _number());
          final end = point(_number(), _number());
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          lastControl = c2;
          current = end;
        case 'S':
          final c1 = lastControl == null ? current : current * 2 - lastControl;
          final c2 = point(_number(), _number());
          final end = point(_number(), _number());
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          lastControl = c2;
          current = end;
        case 'A':
          final rx = _number();
          final ry = _number();
          final rotation = _number();
          final largeArc = _flag();
          final sweep = _flag();
          final end = point(_number(), _number());
          path.arcToPoint(
            end,
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: largeArc,
            clockwise: sweep,
          );
          lastControl = null;
          current = end;
        case 'Z':
          path.close();
          current = start;
          lastControl = null;
        default:
          throw FormatException('Unsupported path command', _data, _at);
      }
    }
    return path;
  }

  void _skipSeparators() {
    while (_at < _data.length && (_data[_at] == ' ' || _data[_at] == ',')) {
      _at++;
    }
  }

  bool _flag() {
    _skipSeparators();
    return _data[_at++] == '1';
  }

  double _number() {
    _skipSeparators();
    final match = RegExp(
      r'[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?',
    ).matchAsPrefix(_data, _at);
    if (match == null) {
      throw FormatException('Expected a number', _data, _at);
    }
    _at = match.end;
    return double.parse(match[0]!);
  }
}
