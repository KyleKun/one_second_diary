import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/url_gateway.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/link_state.dart';

/// Opens the web links of the Settings pages in the browser (Backup
/// tutorial, Source code, Buy me a coffee, GitHub Sponsors, a contributor's
/// profile). When nothing can open one, the state says so, with the link for
/// "Copy link".
class LinkCubit extends Cubit<LinkState> {
  LinkCubit({required this._urls, required this._logger})
    : super(const LinkState());

  final UrlGateway _urls;
  final AppLogger _logger;

  static const String _tag = 'SETTINGS';

  Future<void> open(Uri link) async {
    emit(const LinkState(status: LinkStatus.opening));
    final bool opened = await _urls.open(link);
    if (!opened) _logger.warning(_tag, 'Could not open $link');
    if (isClosed) return;
    emit(
      opened
          ? const LinkState(status: LinkStatus.opened)
          : LinkState(status: LinkStatus.failed, failedLink: link),
    );
  }
}
