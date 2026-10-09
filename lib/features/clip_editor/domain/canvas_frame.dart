import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// A frame made for one canvas. It was zoomed and moved in that canvas's
/// shape, so it holds for profiles of that orientation only: a clip moved
/// to a profile of the other one is framed by default again (and gets its
/// frame back when it returns).
final class CanvasFrame extends Equatable {
  const CanvasFrame({required this.canvas, required this.frame});

  final VideoOrientation canvas;
  final ClipFrame frame;

  @override
  List<Object?> get props => <Object?>[canvas, frame];
}
