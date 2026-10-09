import 'dart:typed_data';

/// One variation axis of a variable font (`fvar`).
typedef FontAxis = ({String tag, double min, double defaultValue, double max});

/// A tiny read-only TrueType/OpenType (sfnt) reader for tests.
///
/// It reads just enough to check the bundled fonts: the code points the
/// `cmap` maps to a glyph, the `OS/2` weight class and the `fvar` axes.
class SfntFont {
  SfntFont(ByteData data) : _data = data, _tables = _readTableDirectory(data);

  final ByteData _data;
  final Map<String, ({int offset, int length})> _tables;

  static Map<String, ({int offset, int length})> _readTableDirectory(
    ByteData data,
  ) {
    final numTables = data.getUint16(4);
    return <String, ({int offset, int length})>{
      for (var i = 0; i < numTables; i++)
        _tag(data, 12 + i * 16): (
          offset: data.getUint32(12 + i * 16 + 8),
          length: data.getUint32(12 + i * 16 + 12),
        ),
    };
  }

  static String _tag(ByteData data, int offset) => String.fromCharCodes(<int>[
    for (var i = 0; i < 4; i++) data.getUint8(offset + i),
  ]);

  int _table(String tag) {
    final table = _tables[tag];
    if (table == null) {
      throw StateError(
        'The font has no "$tag" table (tables: ${_tables.keys.join(', ')})',
      );
    }
    return table.offset;
  }

  /// `OS/2.usWeightClass`, e.g. 400 for Regular and 700 for Bold.
  int get weightClass => _data.getUint16(_table('OS/2') + 4);

  /// The variation axes, or an empty list for a static font.
  List<FontAxis> variationAxes() {
    if (!_tables.containsKey('fvar')) return const <FontAxis>[];
    final fvar = _table('fvar');
    final axesOffset = fvar + _data.getUint16(fvar + 4);
    final axisCount = _data.getUint16(fvar + 8);
    final axisSize = _data.getUint16(fvar + 10);
    return <FontAxis>[
      for (var i = 0; i < axisCount; i++)
        (
          tag: _tag(_data, axesOffset + i * axisSize),
          min: _fixed(axesOffset + i * axisSize + 4),
          defaultValue: _fixed(axesOffset + i * axisSize + 8),
          max: _fixed(axesOffset + i * axisSize + 12),
        ),
    ];
  }

  double _fixed(int offset) => _data.getInt32(offset) / 65536;

  /// Every code point the font maps to a real glyph (glyph id > 0).
  ///
  /// Reads the Unicode full-repertoire subtable (format 12) when present,
  /// otherwise the BMP subtable (format 4).
  Set<int> mappedCodePoints() {
    final cmap = _table('cmap');
    final count = _data.getUint16(cmap + 2);
    int? format4;
    int? format12;
    for (var i = 0; i < count; i++) {
      final record = cmap + 4 + i * 8;
      final platform = _data.getUint16(record);
      final encoding = _data.getUint16(record + 2);
      final subtable = cmap + _data.getUint32(record + 4);
      final format = _data.getUint16(subtable);
      final isUnicode =
          platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
      if (!isUnicode) continue;
      if (format == 12) format12 ??= subtable;
      if (format == 4) format4 ??= subtable;
    }
    if (format12 != null) return _readFormat12(format12);
    if (format4 != null) return _readFormat4(format4);
    throw StateError('The font has no Unicode cmap subtable in format 4 or 12');
  }

  Set<int> _readFormat12(int subtable) {
    final groups = _data.getUint32(subtable + 12);
    final codePoints = <int>{};
    for (var i = 0; i < groups; i++) {
      final group = subtable + 16 + i * 12;
      final start = _data.getUint32(group);
      final end = _data.getUint32(group + 4);
      final startGlyph = _data.getUint32(group + 8);
      for (var codePoint = start; codePoint <= end; codePoint++) {
        if (startGlyph + (codePoint - start) != 0) codePoints.add(codePoint);
      }
    }
    return codePoints;
  }

  Set<int> _readFormat4(int subtable) {
    final segCount = _data.getUint16(subtable + 6) ~/ 2;
    final endCodes = subtable + 14;
    final startCodes = endCodes + segCount * 2 + 2;
    final idDeltas = startCodes + segCount * 2;
    final idRangeOffsets = idDeltas + segCount * 2;
    final codePoints = <int>{};
    for (var segment = 0; segment < segCount; segment++) {
      final end = _data.getUint16(endCodes + segment * 2);
      final start = _data.getUint16(startCodes + segment * 2);
      final delta = _data.getInt16(idDeltas + segment * 2);
      final rangeOffsetAt = idRangeOffsets + segment * 2;
      final rangeOffset = _data.getUint16(rangeOffsetAt);
      for (
        var codePoint = start;
        codePoint <= end && codePoint != 0xFFFF;
        codePoint++
      ) {
        var glyph = 0;
        if (rangeOffset == 0) {
          glyph = (codePoint + delta) & 0xFFFF;
        } else {
          final raw = _data.getUint16(
            rangeOffsetAt + rangeOffset + (codePoint - start) * 2,
          );
          glyph = raw == 0 ? 0 : (raw + delta) & 0xFFFF;
        }
        if (glyph != 0) codePoints.add(codePoint);
      }
    }
    return codePoints;
  }
}
