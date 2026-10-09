/// The soft-subtitle file format: what the app writes for ffmpeg to mux as a
/// clip's `mov_text` stream, and how it reads a clip's subtitle back.
abstract final class SrtCodec {
  /// The placeholder muxed when a stream has to exist without text: one
  /// empty cue from 0 to 1 ms (a zero-length cue does not work).
  static const String emptyCue =
      '1\r\n00:00:00,000 --> 00:00:00,001\r\n\n\n\r\n';

  /// One cue holding [text] for the whole clip:
  ///
  /// - the cue runs from `00:00:00,000` to `endMs - startMs`: the trim is
  ///   input-side, so the clip's timestamps start at 0;
  /// - the index and timing lines end in CRLF, text lines in LF;
  /// - a line longer than 45 characters is wrapped greedily on spaces, and
  ///   every word of it keeps a trailing space; the user's own line breaks
  ///   stay.
  ///
  /// It never puts an empty line inside the cue, which would end it and
  /// lose the text after it: an overlong first word gets no wrap break
  /// before it, and blank lines before any text are dropped, so paragraphs
  /// join with one line break.
  static String encode(
    String text, {
    required int startMs,
    required int endMs,
  }) =>
      '1\r\n${_time(startMs - startMs)} --> ${_time(endMs - startMs)}\r\n'
      '${_wrap(text)}\r\n';

  /// The text of every cue in [srt], lines trimmed and joined with `\n`
  /// (cues too); `''` when there is none. Never throws.
  ///
  /// Reads both what [encode] writes (CRLF, trailing spaces) and what ffmpeg
  /// re-emits when it extracts a clip's `mov_text` stream (LF), whatever the
  /// cue times.
  static String decode(String srt) {
    final List<String> text = <String>[];
    bool inCue = false;
    for (final String line in srt.split('\n')) {
      if (_timing.hasMatch(line)) {
        inCue = true;
      } else if (line.trim().isEmpty) {
        inCue = false;
      } else if (inCue) {
        text.add(line.trim());
      }
    }
    return text.join('\n');
  }

  static const int _wrapAt = 45;

  static final RegExp _timing = RegExp(
    r'^\s*\d+:\d{2}:\d{2}[,.]\d{1,3}\s*-->\s*\d+:\d{2}:\d{2}[,.]\d{1,3}',
  );

  static String _wrap(String text) {
    final StringBuffer content = StringBuffer();
    final List<String> lines = '$text\n'.split('\n');
    final int lastText = lines.lastIndexWhere(
      (String line) => line.trim().isNotEmpty,
    );
    for (final (int index, String line) in lines.indexed) {
      // A blank line before more text would end the cue.
      if (index < lastText && line.trim().isEmpty) continue;
      if (line.length > _wrapAt) {
        String temp = '';
        for (final String word in line.split(' ')) {
          // No break before the first word, however long.
          if (temp.isNotEmpty && temp.length + word.length > _wrapAt) {
            content.write('$temp\n');
            temp = '';
          }
          temp += '$word ';
        }
        content.write('$temp\n');
      } else {
        content.write('$line\n');
      }
    }
    return content.toString();
  }

  /// `HH:MM:SS,mmm`, hours modulo 24.
  static String _time(int ms) {
    final Duration duration = Duration(milliseconds: ms);
    String pad(int value, int width) => value.toString().padLeft(width, '0');
    return '${pad(duration.inHours % 24, 2)}:${pad(duration.inMinutes % 60, 2)}'
        ':${pad(duration.inSeconds % 60, 2)},${pad(ms % 1000, 3)}';
  }
}
