import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/platform/app_info_gateway.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/about_state.dart';

/// About and the licence page: the installed version and its build number,
/// read at runtime (never before the first frame), and the copyright year.
class AboutCubit extends Cubit<AboutState> {
  AboutCubit({required this._appInfo, required Clock clock})
    : super(AboutState(year: clock.now().year));

  final AppInfoGateway _appInfo;

  /// Reads the version and the build number; the page shows them once
  /// they are known.
  Future<void> loadVersion() async {
    final (String version, String? build) = await (
      _appInfo.version(),
      _appInfo.buildNumber(),
    ).wait;
    if (!isClosed) {
      emit(AboutState(year: state.year, version: version, build: build));
    }
  }
}
