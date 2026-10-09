import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_state.dart';

/// The app theme (app-scoped; the app root's `MaterialApp` follows it).
///
/// It shows the stored `isDarkMode`, which bootstrap settled before the
/// first frame (`SettingsRepository.settleThemeOnLaunch`).
///
/// The state follows the stored value (`Setting.changes`), so it can't
/// drift from what a later launch will show.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit({required SettingsRepository settings, required this._logger})
    : _settings = settings,
      super(ThemeState(darkMode: settings.darkMode.value)) {
    _changes = settings.darkMode.changes.listen((bool darkMode) {
      // The switch's own change, announced after it was shown, keeps it.
      if (darkMode == state.darkMode) return;
      emit(ThemeState(darkMode: darkMode, revealed: _revealing));
    });
  }

  final SettingsRepository _settings;
  final AppLogger _logger;
  late final StreamSubscription<bool> _changes;

  /// Whether the change being stored shows through the reveal (the stored
  /// value's own announcement carries it too).
  bool _revealing = false;

  static const String _tag = 'SETTINGS';

  /// The Settings theme switch. When the phone refuses to store it, the
  /// theme stays as it was and the state says so, once per refusal.
  /// [revealed]: the reveal shows the change (see [ThemeState.revealed]).
  Future<void> setDarkMode(bool darkMode, {bool revealed = false}) async {
    emit(state.copyWith(status: ThemeStatus.saving));
    _revealing = revealed;
    try {
      await _settings.darkMode.set(darkMode);
      _logger.info(_tag, 'Dark mode ${darkMode ? 'on' : 'off'}');
      emit(ThemeState(darkMode: darkMode, revealed: revealed));
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not store the theme',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(status: ThemeStatus.saveFailed));
    } finally {
      _revealing = false;
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
