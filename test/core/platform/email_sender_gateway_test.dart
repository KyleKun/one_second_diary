import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/email_sender_gateway.dart';

import '../../support/support.dart';

void main() {
  late FakeUrlGateway urls;
  late EmailSenderGateway gateway;

  setUp(() {
    urls = FakeUrlGateway();
    gateway = EmailSenderGateway(urls: urls);
  });

  group('openMailto', () {
    test('opens a mailto link whose subject and body read as typed (spaces '
        'are %20, never +)', () async {
      await gateway.openMailto(
        recipient: 'kylekundev@gmail.com',
        subject: '[One Second Diary - v2.0.0] Feedback',
        body: 'Hi Kyle!\nA & B',
      );

      expect(
        urls.opened.single.toString(),
        'mailto:kylekundev@gmail.com'
        '?subject=%5BOne%20Second%20Diary%20-%20v2.0.0%5D%20Feedback'
        '&body=Hi%20Kyle!%0AA%20%26%20B',
      );
    });
  });
}
