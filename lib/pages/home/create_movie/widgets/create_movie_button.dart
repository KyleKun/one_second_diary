import 'dart:convert';

import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:wakelock/wakelock.dart';

import '../../../../controllers/video_count_controller.dart';
import '../../../../enums/export_date_range.dart';
import '../../../../routes/app_pages.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/custom_dialog.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/ffmpeg_api_wrapper.dart';
import '../../../../utils/shared_preferences_util.dart';
import '../../../../utils/storage_utils.dart';
import '../../../../utils/utils.dart';

class CreateMovieButton extends StatefulWidget {
  const CreateMovieButton({
    super.key,
    this.selectedExportDateRange,
    this.customSelectedVideos,
    this.customSelectedVideosIsSelected,
  });

  final ExportDateRange? selectedExportDateRange;
  final List<String>? customSelectedVideos;
  final List<bool>? customSelectedVideosIsSelected;

  @override
  _CreateMovieButtonState createState() => _CreateMovieButtonState();
}

class _CreateMovieButtonState extends State<CreateMovieButton> {
  final String logTag = '[CREATE MOVIE] - ';
  final VideoCountController _movieCount = Get.find();
  bool isProcessing = false;
  String progress = '';

  void _openVideo(String filePath) async {
    await OpenFilex.open(filePath);
  }

  void _createMovie() async {
    Wakelock.enable();

    setState(() {
      isProcessing = true;
    });
    try {
      final selectedExportDateRange = widget.selectedExportDateRange;
      final customSelectedVideos = widget.customSelectedVideos;
      List<String> selectedVideos = [];

      if (customSelectedVideos != null && customSelectedVideos.isNotEmpty) {
        for (int i = 0; i < customSelectedVideos.length; i++) {
          if (widget.customSelectedVideosIsSelected![i]) {
            selectedVideos.add(customSelectedVideos[i].split('/').last);
          }
        }
        Utils.logInfo(
            '${logTag}Creating movie with the following custom selected videos: $selectedVideos');
      } else {
        selectedVideos =
            Utils.getSelectedVideosFromStorage(selectedExportDateRange!);
        Utils.logInfo(
            '${logTag}Creating movie in range ${selectedExportDateRange.toString()} with the following videos: $selectedVideos');
      }

      // Needs more than 1 video to create movie
      if (selectedVideos.length < 2) {
        Utils.logWarning(
            '${logTag}Insufficient videos to create movie. Videos: $selectedVideos');
        showDialog(
          barrierDismissible: false,
          context: Get.context!,
          builder: (context) => CustomDialog(
            isDoubleAction: false,
            title: 'movieErrorTitle'.tr,
            content: 'movieInsufficientVideos'.tr,
            actionText: 'Ok',
            actionColor: AppColors.green,
            action: () => Get.back(),
          ),
        );
      } else {
        final snackBar = SnackBar(
          margin: const EdgeInsets.all(10.0),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black54,
          duration: const Duration(seconds: 6),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(25),
            ),
          ),
          content: Text(
            'creatingMovie'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);

        // Get current profile
        final currentProfileName = Utils.getCurrentProfile();

        // Videos folder
        String videosFolder = SharedPrefsUtil.getString('appPath');
        if (currentProfileName.isNotEmpty) {
          videosFolder = '${videosFolder}Profiles/$currentProfileName/';
        } else {
          videosFolder = '$videosFolder';
        }

        Utils.logInfo('${logTag}Base videos folder: $videosFolder');

        // Create a dummy srt for adding subtitles stream if necessary
        final String dummySubtitles = await Utils.writeSrt('', 0);

        // Start checking all videos
        for (String video in selectedVideos) {
          bool isV1point5 = true;
          final String currentVideo = '$videosFolder$video';
          final String tempVideo =
              '${currentVideo.split('.mp4').first}_temp.mp4';

          // TODO(KyleKun): this (in special) will need a good refactor for next version
          // Check if video was recorded before v1.5 so we can process what is needed
          await executeFFprobe(
                  '-v quiet -show_entries format_tags=artist -of default=nw=1:nk=1 $currentVideo')
              .then((session) async {
            final returnCode = await session.getReturnCode();
            if (ReturnCode.isSuccess(returnCode)) {
              final sessionLog = await session.getOutput();
              if (sessionLog == null ||
                  sessionLog.isEmpty ||
                  !sessionLog.contains(Constants.artist)) {
                Utils.logWarning(
                    '$logTag$currentVideo was not recorded on v1.5. Processing it...');
                isV1point5 = false;
              }
            } else {
              final sessionLog = await session.getLogsAsString();
              Utils.logError(
                  '${logTag}Error checking if $currentVideo was recorded on v1.5');
              Utils.logError('${logTag}Error: $sessionLog');
            }
          });

          // Make sure all selected videos have a subtitles and audio stream before creating movie, and finally check their resolution, resizes if necessary.
          if (!isV1point5) {
            // Make sure it is 1080p, h264
            // Also set the framerate to 30 and copy all the streams
            await executeFFmpeg(
                    '-i $currentVideo -vf "scale=1920:1080" -r 30 -map 0 -c:v libx264 -c:a copy -c:s copy -crf 18 $tempVideo -y')
                .then((session) async {
              final returnCode = await session.getReturnCode();
              if (ReturnCode.isSuccess(returnCode)) {
                StorageUtils.deleteFile(currentVideo);
                StorageUtils.renameFile(tempVideo, currentVideo);
                Utils.logInfo(
                    '${logTag}Converted $currentVideo to 1080p, h264');
              } else {
                final sessionLog = await session.getLogsAsString();
                Utils.logError(
                    '${logTag}Error converting $currentVideo to 1080p, h264');
                Utils.logError('${logTag}Error: $sessionLog');
              }
            });

            Utils.logInfo('${logTag}Checking streams for $currentVideo');
            bool hasSubtitles = false;
            bool hasAudio = false;

            // Streams check
            await executeFFprobe(
                    '-v quiet -print_format json -show_format -show_streams $currentVideo')
                .then((session) async {
              final returnCode = await session.getReturnCode();
              if (ReturnCode.isSuccess(returnCode)) {
                final sessionLog = await session.getOutput();
                if (sessionLog == null) return;
                final List<dynamic> streams = jsonDecode(sessionLog)['streams'];
                debugPrint(
                    '${logTag}Streams info for $currentVideo --> $sessionLog');
                for (var stream in streams) {
                  if (stream['codec_type'] == 'audio') {
                    Utils.logWarning('$logTag$currentVideo already has audio!');
                    // Make sure the audio stream is mono
                    await executeFFmpeg(
                            '-i $currentVideo -map 0 -c:v copy -c:a aac -ac 1 -c:s copy $tempVideo -y')
                        .then((session) async {
                      final returnCode = await session.getReturnCode();
                      if (ReturnCode.isSuccess(returnCode)) {
                        StorageUtils.deleteFile(currentVideo);
                        StorageUtils.renameFile(tempVideo, currentVideo);
                        Utils.logInfo(
                            '${logTag}Made sure $currentVideo is mono');
                      } else {
                        final sessionLog = await session.getLogsAsString();
                        Utils.logError(
                            '${logTag}Error converting $currentVideo to mono audio');
                        Utils.logError('${logTag}Error: $sessionLog');
                      }
                    });
                    hasAudio = true;
                  }
                  if (stream['codec_type'] == 'subtitle') {
                    Utils.logWarning(
                        '$logTag$currentVideo already has subtitles!');
                    hasSubtitles = true;
                  }
                }
              }
            });

            // Add audio stream if necessary
            if (!hasAudio) {
              Utils.logInfo(
                  '${logTag}No audio stream for $currentVideo, adding one...');

              // Creates an empty audio stream that matches video duration
              // Set the audio bitrate to 256k and sample rate to 48k (aac codec)
              final command =
                  '-i $currentVideo -f lavfi -i anullsrc=channel_layout=mono:sample_rate=48000 -shortest -b:a 256k -c:v copy -c:a aac $tempVideo -y';
              await executeFFmpeg(command).then((session) async {
                final returnCode = await session.getReturnCode();
                if (ReturnCode.isSuccess(returnCode)) {
                  StorageUtils.deleteFile(currentVideo);
                  StorageUtils.renameFile(tempVideo, currentVideo);
                  Utils.logInfo(
                      '${logTag}Added empty audio stream to $currentVideo');
                } else {
                  final sessionLog = await session.getLogsAsString();
                  Utils.logError(
                      '${logTag}Error adding audio stream to $currentVideo');
                  Utils.logError('${logTag}Error: $sessionLog');
                }
              });
            }

            // Add subtitles stream if necessary
            if (!hasSubtitles) {
              Utils.logInfo(
                  '${logTag}No subtitles stream for $currentVideo, adding one...');
              final command =
                  '-i $currentVideo -i $dummySubtitles -c copy -c:s mov_text $tempVideo -y';
              await executeFFmpeg(command).then((session) async {
                final returnCode = await session.getReturnCode();
                if (ReturnCode.isSuccess(returnCode)) {
                  StorageUtils.deleteFile(currentVideo);
                  StorageUtils.renameFile(tempVideo, currentVideo);
                  Utils.logInfo(
                      '${logTag}Added empty subtitles stream to $currentVideo');
                } else {
                  final sessionLog = await session.getLogsAsString();
                  Utils.logError(
                      '${logTag}Error adding subtitles stream to $currentVideo');
                  Utils.logError('${logTag}Error: $sessionLog');
                }
              });
            }

            // Add artist metadata to avoid redoing all that in this video in the future since it was already processed
            await executeFFmpeg(
                    '-i $currentVideo -metadata artist="${Constants.artist}" -metadata album="Default" -metadata comment="origin=osd_recording_old" -c:v copy -c:a copy -c:s copy $tempVideo -y')
                .then((session) async {
              final returnCode = await session.getReturnCode();
              if (ReturnCode.isSuccess(returnCode)) {
                StorageUtils.deleteFile(currentVideo);
                StorageUtils.renameFile(tempVideo, currentVideo);
                Utils.logInfo(
                    '${logTag}Added artist metadata to $currentVideo');
              } else {
                final sessionLog = await session.getLogsAsString();
                Utils.logError(
                    '${logTag}Error adding artist metadata to $currentVideo');
                Utils.logError('${logTag}Error: $sessionLog');
              }
            });
          }

          if (mounted) {
            setState(() {
              progress =
                  '${selectedVideos.indexOf(video) + 1} / ${selectedVideos.length}';
            });
          } else {
            Utils.logWarning('${logTag}Aborted movie creation!');
            break;
          }

          Utils.logInfo('${logTag}Progress: $progress');
        }

        if (mounted) {
          Utils.logInfo(
              '${logTag}Finished checking videos... creating movie...');

          final String today = DateFormatUtils.getToday();

          // Creating txt that will be used with ffmpeg to concatenate all videos
          final String txtPath = await Utils.writeTxt(selectedVideos);
          final String outputPath =
              '${SharedPrefsUtil.getString('moviesPath')}OSD-Movie-${_movieCount.movieCount.value}-$today.mp4';
          Utils.logInfo('${logTag}Movie will be saved as: $outputPath');

          setState(() {
            progress = '${'creatingMovie'.tr.split('...')[0]}...';
          });

          // Create movie by concatenating all videos
          await executeFFmpeg(
                  '-f concat -safe 0 -i $txtPath -r 30 -map 0 -c copy $outputPath -y')
              .then(
            (session) async {
              final returnCode = await session.getReturnCode();
              if (ReturnCode.isSuccess(returnCode)) {
                _movieCount.increaseMovieCount();
                showDialog(
                  barrierDismissible: false,
                  context: Get.context!,
                  builder: (context) => CustomDialog(
                    isDoubleAction: false,
                    title: 'movieCreatedTitle'.tr,
                    content: 'movieCreatedDesc'.tr,
                    actionText: 'Ok',
                    actionColor: AppColors.green,
                    action: () {
                      Get.offAllNamed(Routes.HOME);
                      Future.delayed(
                        const Duration(milliseconds: 500),
                        () => _openVideo(outputPath),
                      );
                    },
                  ),
                );
                Utils.logInfo('${logTag}Movie saved!');
              } else if (ReturnCode.isCancel(returnCode)) {
                Utils.logWarning('${logTag}Execution was cancelled');
              } else {
                Utils.logError('${logTag}Error creating movie -> $outputPath');
                final sessionLog = await session.getAllLogsAsString();
                final failureStackTrace = await session.getFailStackTrace();
                Utils.logError('${logTag}Session log is: $sessionLog');
                Utils.logError(
                    '${logTag}Failure stacktrace: $failureStackTrace');

                showDialog(
                  barrierDismissible: false,
                  context: Get.context!,
                  builder: (context) => CustomDialog(
                    isDoubleAction: false,
                    title: 'movieError'.tr,
                    sendLogs: true,
                    content:
                        '${'tryAgainMsg'.tr}\nCode error: ${session.getFailStackTrace()}',
                    actionText: 'Ok',
                    actionColor: Colors.red,
                    action: () => Get.offAllNamed(Routes.HOME),
                  ),
                );
              }
            },
          );
        }
      }
    } catch (e) {
      Utils.logError(e);
      showDialog(
        barrierDismissible: false,
        context: Get.context!,
        builder: (context) => CustomDialog(
          isDoubleAction: false,
          title: 'movieError'.tr,
          content: '${'tryAgainMsg'.tr}\n\nError: ${e.toString()}',
          actionText: 'Ok',
          actionColor: Colors.red,
          action: () => Get.offAllNamed(Routes.HOME),
        ),
      );
    } finally {
      Wakelock.disable();
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.6,
      height: MediaQuery.of(context).size.height * 0.11,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mainColor,
          elevation: 5.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(80.0),
          ),
        ),
        onPressed: () {
          if (!isProcessing) _createMovie();
        },
        child: !isProcessing
            ? Text(
                'create'.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.055,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  Text(progress),
                  Text('doNotCloseTheApp'.tr),
                ],
              ),
      ),
    );
  }
}
