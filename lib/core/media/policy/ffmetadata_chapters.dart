import 'package:one_second_diary/core/media/types/movie_chapter.dart';

/// The chapters of a movie as ffmpeg's ffmetadata file (`-i chapters.txt
/// -map_chapters 1` on the concat, `ConcatCommand`), one `[CHAPTER]` per
/// clip.
///
/// ```
/// ;FFMETADATA1
/// [CHAPTER]
/// TIMEBASE=1/1000
/// START=0
/// END=1500
/// title=August 27, 2023 · Berlin · eating bananas with friends
/// ```
///
/// Times are whole milliseconds. Chapters are contiguous: a chapter's END
/// is the next chapter's START and the last END is the movie's length.
/// ffmpeg reads END as the chapter's end bound, which the next chapter's
/// start replaces anyway, so END is exclusive: the clip plays from START
/// up to, not including, END.
///
/// A value is one line: `\`, `=`, `;`, `#` are escaped with a backslash
/// (ffmpeg's rules), line breaks and tabs become a space, and every other
/// control character is dropped, so a title can never start a new key.
abstract final class FfmetadataChapters {
  /// The first line of every ffmetadata file.
  static const String header = ';FFMETADATA1';

  /// The file name the engine writes the chapters under in its job folder.
  static const String fileName = 'chapters.txt';

  /// The file text of [chapters], in their order.
  static String encode(List<MovieChapter> chapters) {
    final StringBuffer text = StringBuffer()..writeln(header);
    for (final MovieChapter chapter in chapters) {
      text
        ..writeln('[CHAPTER]')
        ..writeln('TIMEBASE=1/1000')
        ..writeln('START=${chapter.startMs}')
        ..writeln('END=${chapter.endMs}')
        ..writeln('title=${escape(chapter.title)}');
    }
    return text.toString();
  }

  /// The chapters of [clips] laid end to end from 0, in order: each
  /// chapter starts where the one before ends and lasts the clip's
  /// `durationMs` (a negative one counts as 0). A clip with a null title
  /// takes its time in the movie but makes no chapter.
  static List<MovieChapter> boundaries(
    List<({String? title, int durationMs})> clips,
  ) {
    final List<MovieChapter> chapters = <MovieChapter>[];
    int at = 0;
    for (final (:String? title, :int durationMs) in clips) {
      final int end = at + (durationMs < 0 ? 0 : durationMs);
      if (title != null) {
        chapters.add(MovieChapter(startMs: at, endMs: end, title: title));
      }
      at = end;
    }
    return List<MovieChapter>.unmodifiable(chapters);
  }

  /// [value] as one ffmetadata value line (see the class comment).
  static String escape(String value) => value
      .replaceAll(_lineBreaks, ' ')
      .replaceAll(_controls, '')
      .replaceAllMapped(_special, (Match match) => '\\${match[0]}');

  static final RegExp _lineBreaks = RegExp('[\\n\\r\\t\\v\\f\u0085  ]');
  static final RegExp _controls = RegExp('[\\x00-\\x1F\\x7F-\\x9F]');
  static final RegExp _special = RegExp(r'[\\=;#]');
}
