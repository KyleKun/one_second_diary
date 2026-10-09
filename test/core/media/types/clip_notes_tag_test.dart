import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_notes_tag.dart';

void main() {
  const String device = 'Android 14 (SDK 34), Google Pixel 8';
  final DateTime moment = DateTime(2026, 10, 6, 14, 33, 21, 500);

  // The note is for the user's own files (ffprobe, a future Info sheet):
  // `device=…;app=…;recorded=<local wall time with its UTC offset>`, so
  // the moment and the time zone it was recorded in are both kept.
  test('notes the phone, the app version and the local moment with its '
      'offset; the moment reads back exactly, in any time zone', () {
    final String tag = ClipNotesTag.format(
      device: device,
      appVersion: '2.0.0',
      recordedAt: moment,
    );

    expect(
      tag,
      matches(
        r'^device=Android 14 \(SDK 34\), Google Pixel 8;app=2\.0\.0;'
        r'recorded=2026-10-06T14:33:21\.500[+-]\d\d:\d\d$',
      ),
    );
    final Map<String, String> parts = ClipNotesTag.parse(tag);
    expect(parts, <String, String>{
      'device': device,
      'app': '2.0.0',
      'recorded': parts['recorded']!,
    });
    expect(DateTime.parse(parts['recorded']!).isAtSameMomentAs(moment), isTrue);

    // A UTC moment is written as the phone's wall time, the same instant.
    final Map<String, String> fromUtc = ClipNotesTag.parse(
      ClipNotesTag.format(
        device: device,
        appVersion: '2.0.0',
        recordedAt: moment.toUtc(),
      ),
    );
    expect(
      DateTime.parse(fromUtc['recorded']!).isAtSameMomentAs(moment),
      isTrue,
    );
    expect(fromUtc['recorded'], isNot(endsWith('Z')));
  });

  test('a device description with the separator in it still gives one '
      'part per key; a tag that is not ours reads as nothing', () {
    final Map<String, String> parts = ClipNotesTag.parse(
      ClipNotesTag.format(
        device: ' Pixel; 8; (beta) ',
        appVersion: '2.0.0',
        recordedAt: moment,
      ),
    );
    expect(parts['device'], 'Pixel, 8, (beta)');
    expect(parts['app'], '2.0.0');

    for (final String? garbage in <String?>[
      null,
      '',
      'Shot on my phone',
      ';;;',
      '=value',
    ]) {
      expect(ClipNotesTag.parse(garbage), isEmpty, reason: '$garbage');
    }
  });

  // A place without a GPS fix cannot go into the `location` tag (it would
  // pin the clip at 0°,0°), so it rides in the notes as `place=`, after
  // the device parts when there are any.
  test('a place without a fix is one more part, alone or after the device '
      'note, and reads back', () {
    expect(ClipNotesTag.withPlace(null, ' Home '), 'place=Home');
    expect(ClipNotesTag.withPlace(null, '  '), isNull);
    final String note = ClipNotesTag.format(
      device: device,
      appVersion: '2.0.0',
      recordedAt: moment,
    );
    final String? both = ClipNotesTag.withPlace(note, "Parent's house; Lisbon");
    expect(both, endsWith(";place=Parent's house, Lisbon"));
    expect(ClipNotesTag.parse(both)['place'], "Parent's house, Lisbon");
    expect(ClipNotesTag.parse(both)['app'], '2.0.0');
  });
}
