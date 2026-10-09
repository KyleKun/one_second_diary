import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';

/// Which test of the phone check is running.
enum PhoneCheckTest {
  /// A synthetic encode ([PhoneCheckProgress.format] says which).
  encode,

  /// A decode of a bundled sample.
  decode,

  /// The camera probe.
  camera,

  /// Free space.
  storage,
}

/// Where the phone check stands: the test in flight, as "{done} of
/// {total}" and a label.
final class PhoneCheckProgress extends Equatable {
  const PhoneCheckProgress({
    required this.test,
    required this.done,
    required this.total,
    this.format,
  });

  final PhoneCheckTest test;

  /// Tests finished before this one.
  final int done;

  /// Tests planned, the camera and storage ones included.
  final int total;

  /// The format of an [PhoneCheckTest.encode] test.
  final ClipFormat? format;

  /// 0..1 for the progress bar.
  double get fraction => total == 0 ? 0 : (done / total).clamp(0, 1);

  @override
  List<Object?> get props => <Object?>[test, done, total, format];
}
