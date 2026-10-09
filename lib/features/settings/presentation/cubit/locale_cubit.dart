import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_state.dart';

/// The app language (app-scoped; the app root applies it with
/// `context.setLocale`).
///
/// The language is resolved in one place, `SettingsRepository.appLanguage`
/// (`LocaleResolver`): the language the user picked, else the device
/// language when the app has it, else English. Only a pick stores `lang`,
/// so the app follows the device until the user picks one.
class LocaleCubit extends Cubit<LocaleState> {
  /// [deviceLanguageCode] reads the device locale's language code (without
  /// the region) each time the language is resolved.
  LocaleCubit({
    required SettingsRepository settings,
    required this._deviceLanguageCode,
    required this._logger,
  }) : _settings = settings,
       super(
         LocaleState(
           language: settings.appLanguage(
             deviceLanguageCode: _deviceLanguageCode(),
           ),
         ),
       );

  final SettingsRepository _settings;
  final String Function() _deviceLanguageCode;
  final AppLogger _logger;

  static const String _tag = 'SETTINGS';

  /// The user picked [language]: it is stored in `lang`, and the app
  /// stops following the device. When the phone refuses to
  /// store it, the language stays as it was and the state says so, once
  /// per refusal.
  Future<void> pick(AppLanguage language) async {
    emit(state.copyWith(status: LocaleStatus.saving));
    try {
      await _settings.pickedLanguage.set(language);
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not store the language ${language.code}',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(status: LocaleStatus.saveFailed));
      return;
    }
    _logger.info(_tag, 'App language changed to ${language.code}');
    emit(LocaleState(language: language));
  }

  /// The device locale changed: while no language is picked, the app
  /// follows it (when the app has that language). That is no pick, so the
  /// status of an earlier refused pick is cleared.
  void deviceLanguageChanged() => emit(
    LocaleState(
      language: _settings.appLanguage(
        deviceLanguageCode: _deviceLanguageCode(),
      ),
    ),
  );
}
