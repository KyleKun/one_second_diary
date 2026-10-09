import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';

/// Whether the one-time "What's new: quality" sheet is due: a schema step
/// sets `whatsNewQuality`; any of the sheet's buttons clears it.
enum WhatsNewQualityStatus { unknown, due, shown }

/// The one-time flag behind the "What's new: quality" sheet: [load] reads
/// it, [dismiss] clears it (so the sheet never shows twice, whatever
/// button closed it). Wiring the sheet onto Today is the app's.
class WhatsNewQualityCubit extends Cubit<WhatsNewQualityStatus> {
  WhatsNewQualityCubit({required this._prefs, required this._logger})
    : super(WhatsNewQualityStatus.unknown);

  final PrefsStore _prefs;
  final AppLogger _logger;

  static const String _tag = 'PROFILES';

  /// Reads the flag.
  void load() => emit(
    _prefs.read(PrefKeys.whatsNewQuality)
        ? WhatsNewQualityStatus.due
        : WhatsNewQualityStatus.shown,
  );

  /// Clears the flag: the sheet was shown and answered. A refused write
  /// is logged; the sheet then shows once more on the next launch.
  Future<void> dismiss() async {
    emit(WhatsNewQualityStatus.shown);
    try {
      await _prefs.write(PrefKeys.whatsNewQuality, false);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not clear the "What\'s new: quality" flag',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
