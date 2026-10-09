import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/app_info_gateway.dart';

/// An [AppInfoGateway] reporting [appVersion] and [appBuild].
/// [versionReads] counts the lookups, so a launch test can tell that
/// nothing asked before the first frame.
class FakeAppInfoGateway extends Fake implements AppInfoGateway {
  FakeAppInfoGateway({this.appVersion = '2.0.0', this.appBuild});

  String appVersion;
  String? appBuild;
  int versionReads = 0;

  @override
  Future<String> version() async {
    versionReads++;
    return appVersion;
  }

  @override
  Future<String?> buildNumber() async {
    versionReads++;
    return appBuild;
  }
}
