import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

/// A clip the index knows about, with the file stamp it was seen with.
final class IndexedClip extends Equatable {
  const IndexedClip({required this.ref, required this.stamp});

  final ClipRef ref;
  final FileStamp stamp;

  @override
  List<Object?> get props => <Object?>[ref, stamp];
}
