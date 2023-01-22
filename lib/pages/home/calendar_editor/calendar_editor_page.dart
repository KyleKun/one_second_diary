import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart'
    show CalendarCarousel;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../controllers/daily_entry_controller.dart';
import '../../../controllers/lang_controller.dart';
import '../../../controllers/video_count_controller.dart';
import '../../../routes/app_pages.dart';
import '../../../utils/constants.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/ffmpeg_api_wrapper.dart';
import '../../../utils/shared_preferences_util.dart';
import '../../../utils/theme.dart';
import '../../../utils/utils.dart';
import 'video_subtitles_editor_page.dart';

// TODO(KyleKun): surprise, surprise -> refactor :)
class CalendarEditorPage extends StatefulWidget {
  const CalendarEditorPage({super.key});

  @override
  State<CalendarEditorPage> createState() => _CalendarEditorPageState();
}

class _CalendarEditorPageState extends State<CalendarEditorPage> {
  late List<String> allVideos;
  String? subtitles;
  String currentVideo = '';
  bool wasDateRecorded = false;
  DateTime _selectedDate = DateTime.now();
  late Color mainColor;
  late String appDocDir;
  late String srtFilePath;
  final String _currentDateStr = DateFormatUtils.getToday();
  DateTime lastSelectedDate = DateTime.now();
  final LanguageController _languageController = Get.find();
  final VideoCountController _videoCountController = Get.find();
  final DailyEntryController _dailyEntryController = Get.find();
  VideoPlayerController? _controller;
  final UniqueKey _videoPlayerKey = UniqueKey();
  final mediaStore = MediaStore();

  @override
  void initState() {
    setMediaStorePath();
    mainColor = ThemeService().isDarkTheme() ? Colors.white : Colors.black;
    allVideos = Utils.getAllVideos(fullPath: true);
    setSubtitlesPath();
    initializeTodaysVideoPlayback();
    super.initState();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void setMediaStorePath() {
    final currentProfile = Utils.getCurrentProfile();
    if (currentProfile.isEmpty || currentProfile == 'Default') {
      MediaStore.appFolder = 'OneSecondDiary';
    } else {
      MediaStore.appFolder = 'OneSecondDiary/Profiles/$currentProfile';
    }
  }

  /// Sets the path to save srt file for reading
  void setSubtitlesPath() {
    appDocDir = SharedPrefsUtil.getString('internalDirectoryPath');
    srtFilePath = '$appDocDir/temp.srt';
  }

  /// Reads subtitles from the video file and sets the [subtitles] variable
  Future<void> getSubtitlesForSelectedDate() async {
    final getSubsFile = await executeFFmpeg(
      '-i $currentVideo $srtFilePath -y',
      showInLogs: false,
    );
    final resultCode = await getSubsFile.getReturnCode();
    if (ReturnCode.isSuccess(resultCode)) {
      final srtFileContent = await File(srtFilePath).readAsString();
      subtitles = srtFileContent.isEmpty
          ? ''
          : srtFileContent
              .trim()
              .split('00:00:00,000 --> 00:00:')
              .last
              .substring(6);
    } else {
      subtitles = '';
    }

    if (subtitles?.isNotEmpty == true) {
      debugPrint('Subtitles found in $currentVideo: $subtitles');
    } else {
      debugPrint('No subtitles found in $currentVideo');
    }

    setState(() {});
  }

  /// Initializes the video playback for the current date (today)
  Future<void> initializeTodaysVideoPlayback() async {
    final autoPlay = SharedPrefsUtil.getBool('calendarAutoPlay') ?? true;
    final autoSound = SharedPrefsUtil.getBool('calendarAutoSound') ?? true;
    setState(() {
      wasDateRecorded = allVideos.any((a) => a.contains(_currentDateStr));
      if (wasDateRecorded) {
        currentVideo = allVideos.firstWhere(
          (a) => a.contains(_currentDateStr),
        );
        _controller = VideoPlayerController.file(File(currentVideo))
          ..initialize().then((_) async {
            await _controller?.setLooping(true);
            await _controller?.setVolume(autoSound ? 1.0 : 0.0);
            if (autoPlay) await _controller?.play();
            setState(() {});
          });
      }
    });
    await getSubtitlesForSelectedDate();
  }

  /// Initializes the video playback for the selected date
  Future<void> initializeVideoPlayback(String video) async {
    if (lastSelectedDate != _selectedDate) {
      final autoPlay = SharedPrefsUtil.getBool('calendarAutoPlay') ?? true;
      final autoSound = SharedPrefsUtil.getBool('calendarAutoSound') ?? true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Disposing old controller
        await _controller?.dispose();
        _controller = null;

        // Initing new controller
        _controller = VideoPlayerController.file(File(video))
          ..initialize().then((_) async {
            await _controller?.setLooping(true);
            await _controller?.setVolume(autoSound ? 1.0 : 0.0);
            if (autoPlay) await _controller?.play();
            setState(() {
              lastSelectedDate = _selectedDate;
            });
          });
      });
    }
  }

  /// Picks video from gallery
  Future<void> selectVideoFromGallery() async {
    final rawFile = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );

    // Go to the save video page
    if (rawFile != null) {
      Get.toNamed(
        Routes.SAVE_VIDEO,
        arguments: {
          'videoPath': rawFile.path,
          'currentDate': _selectedDate,
          'isFromRecordingPage': false,
        },
      );
    }
  }

  Future<void> deleteVideoDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        title: Text(
          'discardVideoTitle'.tr,
        ),
        content: Text(
          'deleteVideoWarning'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: ThemeService().isDarkTheme()
                  ? AppColors.light
                  : AppColors.dark,
            ),
            child: Text('no'.tr),
          ),
          TextButton(
            onPressed: () async {
              // Delete current video from storage
              await mediaStore.deleteFile(
                fileName: currentVideo.split('/').last,
                dirType: DirType.video,
                dirName: DirName.dcim,
              );

              Utils.logInfo(
                  '[CALENDAR] - Deleted video from $_currentDateStr: $currentVideo');

              // Reduce the video count recorded by the app
              _videoCountController.reduceVideoCount();

              // If deleted video was today, reset daily recording status
              if (currentVideo.contains(_currentDateStr)) {
                _dailyEntryController.updateDaily(value: false);
              }

              // Refresh the UI
              setState(() {
                allVideos = Utils.getAllVideos(fullPath: true);
                wasDateRecorded = false;
              });

              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('yes'.tr),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: CalendarCarousel<Event>(
            childAspectRatio: 1.25,
            onDayPressed: (DateTime date, List<Event> events) async {
              if (_selectedDate == date) return;
              await _controller?.pause();
              await _changeSelectedDate(date);
            },
            customDayBuilder: (
              bool isSelectable,
              int index,
              bool isSelectedDay,
              bool isToday,
              bool isPrevMonthDay,
              TextStyle textStyle,
              bool isNextMonthDay,
              bool isThisMonthDay,
              DateTime date,
            ) {
              if (allVideos.isNotEmpty) {
                // Get the first recorded video date to not render days before that with day color
                final firstRecVideoDate = DateTime.parse(
                  allVideos.first.split('/').last.split('.').first,
                );
                final hasVideo = allVideos.any(
                  (a) => a.contains(
                    DateFormatUtils.getDate(
                      date,
                      allowCheckFormattingDayFirst: false,
                    ),
                  ),
                );
                // Do not colorize days before first recording date or future dates
                if (DateTime.now().compareTo(date) != -1 &&
                    firstRecVideoDate.compareTo(date) != 1) {
                  return Center(
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        color: hasVideo ? AppColors.green : AppColors.mainColor,
                        fontFamily: 'Magic',
                      ),
                    ),
                  );
                } else {
                  return null;
                }
              }
              return null;
            },
            selectedDayBorderColor: mainColor,
            selectedDayButtonColor: Colors.transparent,
            weekendTextStyle: TextStyle(
              color: mainColor,
              fontFamily: 'Magic',
            ),
            thisMonthDayBorderColor: Colors.transparent,
            todayButtonColor: Colors.transparent,
            todayBorderColor: Colors.grey,
            todayTextStyle: TextStyle(
              fontFamily: 'Magic',
              color: mainColor,
            ),
            inactiveDaysTextStyle: const TextStyle(
              fontFamily: 'Magic',
            ),
            weekdayTextStyle: TextStyle(
              fontFamily: 'Magic',
              color: mainColor,
              fontWeight: FontWeight.w900,
            ),
            weekFormat: false,
            iconColor:
                ThemeService().isDarkTheme() ? Colors.white : Colors.black,
            headerTextStyle: TextStyle(
              fontFamily: 'Magic',
              fontSize: 20.0,
              color: mainColor,
            ),
            locale: _languageController.selectedLanguage.value,
            shouldShowTransform: false,
            pageSnapping: true,
            height: MediaQuery.of(context).size.height * 0.42,
            showOnlyCurrentMonthDate: true,
            selectedDateTime: _selectedDate,
            daysHaveCircularBorder: true,
            daysTextStyle: TextStyle(
              fontFamily: 'Magic',
              color: mainColor,
            ),
          ),
        ),
        Expanded(
          child: wasDateRecorded
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: mainColor),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: SizedBox(
                                  height: 30,
                                  width: 30,
                                  child: Icon(
                                    Icons.hourglass_bottom,
                                    color: mainColor,
                                  ),
                                ),
                              ),
                              FutureBuilder(
                                future: initializeVideoPlayback(currentVideo),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox();
                                  }

                                  if (snapshot.hasError) {
                                    return Text(
                                      '"Error loading video: " + ${snapshot.error}',
                                    );
                                  }

                                  // Not sure if it works but if the videoController fails we try to restart the page
                                  if (_controller?.value.hasError == true) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      _controller?.dispose();
                                    });
                                    Get.offAllNamed(Routes.HOME)
                                        ?.then((_) => setState(() {}));
                                  }

                                  // VideoPlayer
                                  if (_controller != null &&
                                      _controller!.value.isInitialized) {
                                    return Align(
                                      alignment: Alignment.center,
                                      child: Stack(
                                        fit: StackFit.passthrough,
                                        children: [
                                          Align(
                                            alignment: Alignment.center,
                                            child: ClipRect(
                                              child: VideoPlayer(
                                                key: _videoPlayerKey,
                                                _controller!,
                                              ),
                                            ),
                                          ),
                                          Controls(
                                            controller: _controller,
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    return const SizedBox();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mainColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                            ),
                            onPressed: () async {
                              await pauseOrResumeVideoPlayback(
                                _controller,
                                forcePause: true,
                              );
                              await deleteVideoDialog();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                'deleteVideo'.tr,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: subtitles?.isEmpty == true
                                  ? AppColors.green
                                  : AppColors.purple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                            ),
                            onPressed: () async {
                              await pauseOrResumeVideoPlayback(
                                _controller,
                                forcePause: true,
                              );
                              Get.to(
                                VideoSubtitlesEditorPage(
                                  videoPath: currentVideo,
                                  subtitles: subtitles ?? '',
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                subtitles?.isEmpty == true
                                    ? 'addSubtitles'.tr
                                    : 'editSubtitles'.tr,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('noVideoRecorded'.tr),
                    const SizedBox(
                      height: 10.0,
                    ),
                    if (!_selectedDate.isAfter(DateTime.now()))
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                          ),
                          onPressed: () async {
                            Utils.logInfo(
                                '[CALENDAR] add video button pressed for date $_currentDateStr');
                            await selectVideoFromGallery();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'addVideo'.tr,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Sets the [_selectedDate] to the given [date] and checks if there is a video for that date
  Future<void> _changeSelectedDate(DateTime date) async {
    setState(
      () => _selectedDate = date,
    );

    final currentVideoExists = allVideos.any(
      (a) => a.contains(
        DateFormatUtils.getDate(
          date,
          allowCheckFormattingDayFirst: false,
        ),
      ),
    );
    if (currentVideoExists) {
      setState(() {
        wasDateRecorded = true;
        currentVideo = allVideos.firstWhere(
          (a) => a.contains(
            DateFormatUtils.getDate(
              date,
              allowCheckFormattingDayFirst: false,
            ),
          ),
        );
      });
      await getSubtitlesForSelectedDate();
    } else {
      setState(() {
        wasDateRecorded = false;
      });
    }
  }
}

/// Pause or Resume videoplayback
Future<void> pauseOrResumeVideoPlayback(
  VideoPlayerController? controller, {
  bool forcePause = false,
}) async {
  if (controller?.value.isInitialized != true) return;

  if (!controller!.value.isPlaying && !forcePause) {
    await controller.play();
    SharedPrefsUtil.putBool('calendarAutoPlay', true);
  } else {
    await controller.pause();
    SharedPrefsUtil.putBool('calendarAutoPlay', false);
  }
}

/// Controls for the video player
class Controls extends StatefulWidget {
  const Controls({super.key, required this.controller});

  final VideoPlayerController? controller;

  @override
  State<Controls> createState() => _ControlsState();
}

class _ControlsState extends State<Controls> {
  late IconData playIcon;
  late IconData soundIcon;

  @override
  void initState() {
    if (widget.controller?.value.isPlaying == true) {
      playIcon = Icons.pause;
    } else {
      playIcon = Icons.play_arrow;
    }

    if (widget.controller?.value.volume == 0) {
      soundIcon = Icons.volume_off;
    } else {
      soundIcon = Icons.volume_up;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await pauseOrResumeVideoPlayback(widget.controller);
        final isPlaying = widget.controller!.value.isPlaying;
        setState(() {
          playIcon = isPlaying ? Icons.pause : Icons.play_arrow;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {
              final bool isMuted = widget.controller!.value.volume == 0;
              if (isMuted) {
                SharedPrefsUtil.putBool('calendarAutoSound', true);
                widget.controller!.setVolume(1);
                setState(() {
                  soundIcon = Icons.volume_up;
                });
              } else {
                SharedPrefsUtil.putBool('calendarAutoSound', false);
                widget.controller!.setVolume(0);
                setState(() {
                  soundIcon = Icons.volume_off;
                });
              }
            },
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Icon(
                  soundIcon,
                  color: Colors.white,
                  shadows: [
                    const Shadow(
                      blurRadius: 10.0,
                      color: Colors.black,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Icon(
                playIcon,
                color: Colors.white,
                shadows: [
                  const Shadow(
                    blurRadius: 10.0,
                    color: Colors.black,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
