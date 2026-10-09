import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_key.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';

/// Keeps writing the preferences only older builds read, so the user can
/// downgrade.
///
/// The app derives all of these (from `AppPaths`, the clip index, the clock
/// and the device) and never reads them back.
final class LegacyPrefsMirror {
  LegacyPrefsMirror({required this._prefs});

  final PrefsStore _prefs;

  /// The resolved folders, written every launch. Older builds read them
  /// after a downgrade.
  Future<void> writePathKeys(AppPaths paths) async {
    await _write(PrefKeys.internalDirectoryPath, paths.internal);
    await _write(PrefKeys.appPath, paths.videos);
    await _write(PrefKeys.moviesPath, paths.movies);
  }

  /// The active profile's counters as older builds cache them: `videoCount`
  /// = [daysRecorded] (bare-name clips, without the extra `-N` clips of a
  /// day), `dailyEntry` = [todayRecorded], and `today` = [today] as
  /// `yyyy-MM-dd`.
  ///
  /// Older builds force-unwrap `videoCount`, so it must always be stored (a
  /// value already stored is not written again). Call it whenever the active
  /// profile or its clips change, and at midnight.
  Future<void> writeClipCounters({
    required int daysRecorded,
    required bool todayRecorded,
    required LocalDay today,
  }) async {
    RangeError.checkNotNegative(daysRecorded, 'daysRecorded');
    await _write(PrefKeys.videoCount, daysRecorded);
    await _write(PrefKeys.dailyEntry, todayRecorded);
    await _write(PrefKeys.today, today.fileStem);
  }

  /// `videoCount = 0` and `movieCount = 1`, the first-run values older
  /// builds expect. They force-unwrap both, so onboarding writes them
  /// before it marks the user onboarded.
  ///
  /// A counter that is already stored is kept: onboarding may run again
  /// after a kill, and resetting `movieCount` to 1 would let a downgraded
  /// build overwrite an existing movie.
  Future<void> writeFirstRunCounters() async {
    if (!_prefs.contains(PrefKeys.videoCount)) {
      await _prefs.write(PrefKeys.videoCount, 0);
    }
    if (!_prefs.contains(PrefKeys.movieCount)) {
      await _prefs.write(PrefKeys.movieCount, 1);
    }
  }

  /// The Android `Build.VERSION.SDK_INT` ([sdkInt]), written every Android
  /// start (below 29 it forces the native camera). Pass the
  /// `DeviceInfoGateway` answer as is: null (iOS) writes nothing, because
  /// the key is never written on iOS.
  Future<void> writeSdkVersion(int? sdkInt) async {
    if (sdkInt == null) return;
    await _write(PrefKeys.sdkVersion, sdkInt);
  }

  /// Writes [value] unless [key] already holds it: on Android every write
  /// is a full commit of the preferences file, and the clip counters are
  /// written on every index change.
  ///
  /// A value equal to the key's default is always written, because `read`
  /// also returns the default for a key stored with another type, which a
  /// downgraded build could not read.
  Future<void> _write<T>(PrefKey<T> key, T value) async {
    if (value != key.defaultValue && _prefs.read(key) == value) return;
    await _prefs.write(key, value);
  }
}
