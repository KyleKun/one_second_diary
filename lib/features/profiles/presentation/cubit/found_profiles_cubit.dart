import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_change.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/found_profiles_state.dart';

/// The profile list's "Found on this phone": folders under `Profiles/` that
/// hold clips but that no profile lists, after a reinstall or a delete whose
/// clips the phone kept. "Add back" lists the folder as a profile (not
/// active). The list is read again after every profile added or removed.
class FoundProfilesCubit extends Cubit<FoundProfilesState> {
  FoundProfilesCubit({required this._profiles, required this._logger})
    : super(FoundProfilesState()) {
    _changes = _profiles.changes.listen((ProfileChange _) => unawaited(load()));
  }

  final ProfilesRepository _profiles;
  final AppLogger _logger;
  late final StreamSubscription<ProfileChange> _changes;

  static const String _tag = 'PROFILES';

  /// Reads the folders the phone holds.
  Future<void> load() async {
    final List<ProfileKey> folders = await _profiles.foundOnThisPhone();
    if (!isClosed) {
      emit(state.copyWith(folders: folders, status: FoundProfilesStatus.ready));
    }
  }

  /// Lists [folder] as a profile.
  Future<void> addBack(ProfileKey folder) async {
    emit(state.copyWith(status: FoundProfilesStatus.adding));
    try {
      await _profiles.addFound(folder);
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not add back the folder "${folder.value}"',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) {
        emit(state.copyWith(status: FoundProfilesStatus.addFailed));
      }
      return;
    }
    await load();
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
