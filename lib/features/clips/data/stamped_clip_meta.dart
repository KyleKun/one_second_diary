import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

/// A cached [meta] and the [stamp] of the file it describes. The cache
/// serves [meta] only while the clip still has that stamp.
final class StampedClipMeta extends Equatable {
  const StampedClipMeta({required this.stamp, required this.meta});

  final FileStamp stamp;
  final ClipMeta meta;

  @override
  List<Object?> get props => <Object?>[stamp, meta];
}
