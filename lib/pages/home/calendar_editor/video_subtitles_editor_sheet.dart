import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../../utils/app_paths.dart';
import '../../../utils/constants.dart';
import '../../../utils/ffmpeg_api_wrapper.dart';
import '../../../utils/media_gallery.dart';
import '../../../utils/storage_utils.dart';
import '../../../utils/theme.dart';
import '../../../utils/utils.dart';

/// Adds or edits the subtitles embedded in an already-saved video, as a
/// bottom sheet over the calendar (whose own preview of the video stays
/// visible above it) — same look as the subtitles sheet on the save page.
class VideoSubtitlesEditorSheet extends StatefulWidget {
  const VideoSubtitlesEditorSheet({
    super.key,
    required this.videoPath,
    required this.subtitles,
  });

  final String videoPath;
  final String subtitles;

  /// Resolves to true once the video was re-saved with the new subtitles,
  /// false if the sheet was closed without saving or saving failed.
  static Future<bool> show(
    BuildContext context, {
    required String videoPath,
    required String subtitles,
  }) async {
    final bool isDark = ThemeService().isDarkTheme();
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.dark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          VideoSubtitlesEditorSheet(videoPath: videoPath, subtitles: subtitles),
    );
    return saved == true;
  }

  @override
  State<VideoSubtitlesEditorSheet> createState() =>
      _VideoSubtitlesEditorSheetState();
}

class _VideoSubtitlesEditorSheetState extends State<VideoSubtitlesEditorSheet> {
  final logTag = '[SUBTITLES EDITOR] - ';
  bool isProcessing = false;
  bool isEdit = false;
  final TextEditingController subtitlesController = TextEditingController();

  // Only needed for the video's duration, which the .srt cue spans.
  late final VideoPlayerController _videoController;
  bool _isVideoReady = false;

  late final bool isDarkTheme = ThemeService().isDarkTheme();
  Color get _textColor => isDarkTheme ? Colors.white : AppColors.dark;
  Color get _mutedTextColor => isDarkTheme ? Colors.white60 : Colors.black54;
  Color get _fieldColor => isDarkTheme
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.04);

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        if (mounted) setState(() => _isVideoReady = true);
      });
    if (widget.subtitles.isNotEmpty) {
      subtitlesController.text = widget.subtitles
          .trim()
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      isEdit = true;
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    subtitlesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (isProcessing || !_isVideoReady) return;
    setState(() => isProcessing = true);

    // Grabbed up front: the sheet may be gone by the time saving finishes.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    final subtitles = await Utils.writeSrt(
      subtitlesController.text,
      0,
      _videoController.value.duration.inMilliseconds,
    );

    final String videoTempName = widget.videoPath.split('/').last;
    final String tempFilePath = '${AppPaths.internal}/$videoTempName';

    if (isEdit) {
      Utils.logWarning('${logTag}Editing subtitles for ${widget.videoPath}');
    } else {
      Utils.logWarning(
        '${logTag}Adding brand new subtitles for ${widget.videoPath}',
      );
    }

    final String command =
        '-i "${widget.videoPath}" -i $subtitles -c:s mov_text -c:v copy -c:a copy -map 0:v -map 0:a? -map 1 -disposition:s:0 default "$tempFilePath" -y';

    bool saved = false;
    final session = await executeFFmpeg(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      Utils.logInfo('${logTag}Video subtitles updated successfully!');
      // Replace the original with the re-muxed copy
      await StorageUtils.deleteVideo(widget.videoPath);
      await MediaGallery.instance.save(
        tempFilePath: tempFilePath,
        destinationPath: widget.videoPath,
      );
      saved = true;
      messenger.showSnackBar(SnackBar(content: Text('subtitlesSaved'.tr)));
    } else {
      Utils.logError('${logTag}Video subtitles update failed!');
      final sessionLog = await session.getLogsAsString();
      final failureStackTrace = await session.getFailStackTrace();
      Utils.logError('${logTag}Session log: $sessionLog');
      Utils.logError('${logTag}Failure stacktrace: $failureStackTrace');
      messenger.showSnackBar(SnackBar(content: Text('tryAgainMsg'.tr)));
    }

    if (mounted) {
      setState(() => isProcessing = false);
      navigator.pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: 1.5),
    );

    return PopScope(
      // Don't let the back button close the sheet mid-save.
      canPop: !isProcessing,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkTheme ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.yellow.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.subtitles_rounded,
                        color: AppColors.yellow,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit ? 'editSubtitles'.tr : 'addSubtitles'.tr,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  autofocus: true,
                  enabled: !isProcessing,
                  controller: subtitlesController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 8,
                  cursorColor: AppColors.mainColor,
                  style: TextStyle(
                    fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                    fontSize: 16,
                    height: 1.4,
                    color: _textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'enterSubtitles'.tr.split('(').first.trim(),
                    hintStyle: TextStyle(color: _mutedTextColor),
                    filled: true,
                    fillColor: _fieldColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: border(Colors.transparent),
                    disabledBorder: border(Colors.transparent),
                    focusedBorder: border(AppColors.mainColor),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                      disabledBackgroundColor: AppColors.mainColor.withValues(
                        alpha: 0.6,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isProcessing || !_isVideoReady ? null : _save,
                    child: isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'save'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
