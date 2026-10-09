import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_state.dart';

/// The user's optional name, app-scoped: onboarding's name field and
/// Settings' "Your name" row set it; Today's greeting and the saved
/// snackbar read it (`context.select<UserNameCubit, String>`).
///
/// The state follows the stored `userName` (`Setting.changes`), so it can't
/// drift from what a later launch shows, whoever wrote it. The name itself
/// never reaches the log.
class UserNameCubit extends Cubit<UserNameState> {
  UserNameCubit({required SettingsRepository settings, required this._logger})
    : _settings = settings,
      super(UserNameState(name: settings.userName.value)) {
    _changes = settings.userName.changes.listen(
      (String name) => emit(UserNameState(name: name)),
    );
  }

  final SettingsRepository _settings;
  final AppLogger _logger;
  late final StreamSubscription<String> _changes;

  /// The longest name: onboarding's name field and the "Your name" sheet
  /// both stop there, so neither cuts a name the other took.
  static const int maxLength = 30;

  static const String _tag = 'SETTINGS';

  /// Stores [name], trimmed; a blank one clears it. When the phone refuses,
  /// the name stays as it was and the state says so, once per refusal.
  Future<void> rename(String name) async {
    emit(state.copyWith(status: UserNameStatus.saving));
    try {
      await _settings.userName.set(name);
      final String stored = _settings.userName.value;
      _logger.info(
        _tag,
        stored.isEmpty ? 'User name cleared' : 'User name set',
      );
      emit(UserNameState(name: stored));
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not store the user name',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(status: UserNameStatus.saveFailed));
    }
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
