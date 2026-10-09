import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/srt_codec.dart';

void main() {
  group('SrtCodec.encode (v1.7 Utils.writeSrt)', () {
    // Each row: (text, start, end, file). One cue from 0 to the clip length
    // with a CRLF header; cue times relative to the trim start (the trim is
    // input-side); lines over 45 characters wrapped on spaces, trailing
    // spaces kept; the user's line breaks kept; the empty placeholder cue
    // 0 -> 1 ms (a zero-length cue does not work).
    test('is byte-identical to v1.7 over a corpus', () {
      expect(
        SrtCodec.emptyCue,
        '1\r\n00:00:00,000 --> 00:00:00,001\r\n\n\n\r\n',
      );
      const List<(String, int, int, String)> cases =
          <(String, int, int, String)>[
            ('', 0, 1, '1\r\n00:00:00,000 --> 00:00:00,001\r\n\n\n\r\n'),
            ('', 0, 1500, '1\r\n00:00:00,000 --> 00:00:01,500\r\n\n\n\r\n'),
            (
              'Hello',
              0,
              1500,
              '1\r\n00:00:00,000 --> 00:00:01,500\r\nHello\n\n\r\n',
            ),
            (
              'Hello',
              1234,
              2734,
              '1\r\n00:00:00,000 --> 00:00:01,500\r\nHello\n\n\r\n',
            ),
            (
              'Walk around Asakusa',
              0,
              10000,
              '1\r\n00:00:00,000 --> 00:00:10,000\r\n'
                  'Walk around Asakusa\n\n\r\n',
            ),
            (
              'First time at Senso-ji. Way more crowded than I imagined it '
                  'would be today',
              0,
              1500,
              '1\r\n00:00:00,000 --> 00:00:01,500\r\n'
                  'First time at Senso-ji. Way more crowded than \n'
                  'I imagined it would be today \n'
                  '\n'
                  '\r\n',
            ),
            (
              'first line\n'
                  'this second line is definitely longer than forty five '
                  'chars',
              0,
              2000,
              '1\r\n00:00:00,000 --> 00:00:02,000\r\n'
                  'first line\n'
                  'this second line is definitely longer than \n'
                  'forty five chars \n'
                  '\n\r\n',
            ),
            (
              'a b c',
              700,
              1700,
              '1\r\n00:00:00,000 --> 00:00:01,000\r\na b c\n\n\r\n',
            ),
            (
              'Long clip',
              0,
              65000,
              '1\r\n00:00:00,000 --> 00:01:05,000\r\nLong clip\n\n\r\n',
            ),
            (
              'Hours',
              0,
              3600000 + 61001,
              '1\r\n00:00:00,000 --> 01:01:01,001\r\nHours\n\n\r\n',
            ),
            (
              '  spaced  words  here  that  go  on  and  on  and  on  ',
              0,
              900,
              '1\r\n00:00:00,000 --> 00:00:00,900\r\n'
                  '  spaced  words  here  that  go  on  and  on  \n'
                  'and  on   \n\n\r\n',
            ),
            (
              'Ünïcödé 東京 Москва — emoji 🎥 and more text to wrap here',
              0,
              999,
              '1\r\n00:00:00,000 --> 00:00:00,999\r\n'
                  'Ünïcödé 東京 Москва — emoji 🎥 and more text to \n'
                  'wrap here \n\n\r\n',
            ),
            (
              'ends with newline\n',
              5,
              6,
              '1\r\n00:00:00,000 --> 00:00:00,001\r\n'
                  'ends with newline\n\n\n\r\n',
            ),
            (
              'negative',
              2000,
              1000,
              '1\r\n00:00:00,000 --> 00:00:59,000\r\nnegative\n\n\r\n',
            ),
          ];
      for (final (String text, int start, int end, String v17) in cases) {
        expect(
          SrtCodec.encode(text, startMs: start, endMs: end),
          v17,
          reason: '($text, $start, $end)',
        );
      }
    });

    // An empty line inside the cue ends it, and a player (like decode) drops
    // the text after it. A first word over 45 characters stays on the first
    // line and the words after it still wrap. A blank line typed by the user
    // is dropped (leading ones too); the paragraphs join with one line break.
    test('never an empty line inside the cue (O6)', () {
      final String long = 'x' * 50;
      final List<(String, String?, String)> cases = <(String, String?, String)>[
        (long, '1\r\n00:00:00,000 --> 00:00:01,000\r\n$long \n\n\r\n', long),
        (
          '$long and then a few more words',
          null,
          '$long\nand then a few more words',
        ),
        (
          'first\n\n  \nsecond',
          '1\r\n00:00:00,000 --> 00:00:01,000\r\nfirst\nsecond\n\n\r\n',
          'first\nsecond',
        ),
        ('\n\nlate', null, 'late'),
      ];
      for (final (String text, String? bytes, String readBack) in cases) {
        final String srt = SrtCodec.encode(text, startMs: 0, endMs: 1000);
        if (bytes != null) expect(srt, bytes, reason: text);
        expect(SrtCodec.decode(srt), readBack, reason: text);
      }
    });
  });

  group('SrtCodec.decode', () {
    // What ffmpeg re-emits when it extracts a clip's mov_text stream (LF
    // line ends), encode's CRLF output (wrapped lines trimmed), several cues
    // joined.
    test('reads the cue text, cues ending at 60 s or later included', () {
      final Map<String, String> cases = <String, String>{
        '1\n00:00:00,000 --> 00:00:01,500\nHello world\n\n': 'Hello world',
        SrtCodec.encode(
          'First time at Senso-ji. Way more crowded than I imagined it '
          'would be today',
          startMs: 0,
          endMs: 1500,
        ): 'First time at Senso-ji. Way more crowded than\n'
            'I imagined it would be today',
        '1\n00:00:00,000 --> 00:01:05,000\nLong clip\n\n': 'Long clip',
        '1\n00:00:02,000 --> 01:00:00,000\nLater start\n': 'Later start',
        SrtCodec.emptyCue: '',
        '1\n00:00:00,000 --> 00:00:00,001\n\n\n': '',
        '1\r\n00:00:00,000 --> 00:00:01,000\r\nOne\r\n\r\n'
                '2\r\n00:00:01,000 --> 00:00:02,000\r\nTwo\r\nlines\r\n':
            'One\nTwo\nlines',
      };
      for (final MapEntry<String, String>(key: String srt, value: String text)
          in cases.entries) {
        expect(SrtCodec.decode(srt), text, reason: srt);
      }
    });

    test('never throws: anything else is no text', () {
      for (final String srt in <String>[
        '',
        '1\nab',
        'ab',
        'garbage without a cue\nline two',
        '-->',
        '\r\n\r\n',
      ]) {
        expect(SrtCodec.decode(srt), '', reason: srt);
      }
    });

    test('round-trips text the writer does not wrap', () {
      for (final String text in <String>[
        'Hello',
        'Walk around Asakusa before the rain',
        'first line\nsecond line',
        'Москва, 東京, São Paulo',
        'home --> office',
        '1\n2\n3',
      ]) {
        expect(
          SrtCodec.decode(SrtCodec.encode(text, startMs: 0, endMs: 1000)),
          text,
        );
      }
    });

    // The extracted text flattened to one line, for cues ending before 60 s.
    test('shows what v1.7 showed wherever v1.7 could read the file', () {
      // What ffmpeg re-emits for a clip saved with [text]: LF line ends.
      String extracted(String text, int endMs) => SrtCodec.encode(
        text,
        startMs: 0,
        endMs: endMs,
      ).replaceAll('\r\n', '\n');
      String flattened(String text) =>
          text.trim().replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
      const Map<String, String> v17Prefill = <String, String>{
        '': '',
        'Hello': 'Hello',
        'Walk around Asakusa': 'Walk around Asakusa',
        'First time at Senso-ji. Way more crowded than I imagined it would '
                'be today':
            'First time at Senso-ji. Way more crowded than I imagined it '
            'would be today',
        'first line\nsecond line': 'first line second line',
      };
      for (final MapEntry<String, String>(key: String text, value: String v17)
          in v17Prefill.entries) {
        for (final int endMs in <int>[1, 1500, 59999]) {
          final String srt = extracted(text, endMs);
          expect(flattened(SrtCodec.decode(srt)), v17, reason: srt);
        }
      }
    });
  });
}
