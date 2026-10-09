import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/url_gateway.dart';

/// A [UrlGateway] that records [opened] links and answers [result].
class FakeUrlGateway extends Fake implements UrlGateway {
  final List<Uri> opened = <Uri>[];
  bool result = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}
