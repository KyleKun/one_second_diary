import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/platform/app_info_gateway.dart';
import 'package:one_second_diary/core/platform/share_gateway.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/settings_state.dart';

/// The Settings tab: the app version for the About row and sharing the
/// app. Its links open through the tab's `LinkCubit`; the rows that change
/// a setting talk to the app-scoped cubits (theme, language, name,
/// profiles) and to the reminder settings.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({required this._appInfo, required this._share})
    : super(const SettingsState());

  final AppInfoGateway _appInfo;
  final ShareGateway _share;

  Future<void> loadVersion() async {
    final String version = await _appInfo.version();
    if (!isClosed) emit(SettingsState(version: version));
  }

  /// "Share with a friend": [text] (in the app language, with the store
  /// link) in the system share sheet, anchored on [origin] (iPad).
  Future<void> shareApp({required String text, Rect? origin}) =>
      _share.shareText(text, origin: origin);
}
