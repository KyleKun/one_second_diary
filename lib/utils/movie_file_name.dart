/// Names the movies the app generates: `OSD-Movie-<count>-<date>.mp4`.
///
/// The count is the stored "next movie number", but the Movies folder can
/// hold files the counter does not know about: a reinstall (or a device
/// restore) resets the preferences while the old movies stay on disk, and on
/// Android those old files belong to the previous install. Writing over one
/// of them fails with "Permission denied", and asking MediaStore to replace
/// one would need the user's consent. So the name has to be one the folder
/// doesn't contain yet.
class MovieFileName {
  MovieFileName._();

  /// The file name for movie number [count] created on [date].
  static String build(int count, String date) => 'OSD-Movie-$count-$date.mp4';

  /// The first count, starting at [startCount], whose [build] name [exists]
  /// rejects.
  ///
  /// [exists] is given the bare file name, not a path, so the caller decides
  /// which folder it is checked against.
  static int firstFreeCount({
    required int startCount,
    required String date,
    required bool Function(String fileName) exists,
  }) {
    int count = startCount;
    while (exists(build(count, date))) {
      count++;
    }
    return count;
  }
}
