import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart'
    show CalendarCarousel;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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
  final LanguageController _languageController = Get.find();
  final VideoCountController _videoCountController = Get.find();
  final DailyEntryController _dailyEntryController = Get.find();

  @override
  void initState() {
    mainColor = ThemeService().isDarkTheme() ? Colors.white : Colors.black;
    allVideos = Utils.getAllVideos(fullPath: true);
    getSubtitlesPath();
    getTodaysThumbnail();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void getSubtitlesPath() {
    appDocDir = SharedPrefsUtil.getString('internalDirectoryPath');
    srtFilePath = '$appDocDir/temp.srt';
  }

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
          : srtFileContent.trim().split(',000').last;
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

  Future<void> getTodaysThumbnail() async {
    setState(() {
      wasDateRecorded = allVideos.any((a) => a.contains(_currentDateStr));
      if (wasDateRecorded) {
        currentVideo = allVideos.firstWhere(
          (a) => a.contains(_currentDateStr),
        );
      }
    });
    await getSubtitlesForSelectedDate();
  }

  Future<void> getSelectedDateThumbnail() async {
    final parsedDate = DateFormatUtils.getDate(_selectedDate);
    setState(() {
      wasDateRecorded = allVideos.any((a) => a.contains(parsedDate));
      if (wasDateRecorded) {
        currentVideo = allVideos.firstWhere(
          (a) => a.contains(parsedDate),
        );
      }
    });
    await getSubtitlesForSelectedDate();
  }

  Future<Uint8List?> getThumbnail(String video) async {
    final thumbnail = await VideoThumbnail.thumbnailData(
      video: File(video).path,
      imageFormat: ImageFormat.JPEG,
      quality: 12,
    );
    return thumbnail;
  }

  Future<void> selectVideoFromGallery() async {
    final rawFile = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );

    if (rawFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'processingVideo'.tr,
          ),
        ),
      );

      // Video validation before navigation to the video editing page
      final bool isVideoValid =
          await _validateInputVideo(rawFile.path, context);

      // Go to the save video page
      if (isVideoValid) {
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
  }

  // Ensure the video passes all validations before processing
  Future<bool> _validateInputVideo(
      String videoPath, BuildContext context) async {
    return await executeFFprobe(
            '-v error -print_format json -show_format -select_streams v:0 -show_streams $videoPath')
        .then((session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        final sessionLog = await session.getOutput();
        if (sessionLog == null) return false;
        final Map<String, dynamic> videoStreamDetails =
            jsonDecode(sessionLog)['streams'][0];

        final num videoWidth = videoStreamDetails['width'];
        final num videoHeight = videoStreamDetails['height'];

        // Check for video orientation before saving video.
        // In some videos, the rotation property is not explicity defined which will cause ffprobe to return a null value,
        // so the workaround here compares the values of video width & height to determine the orientation

        // The orientation is always portrait whenever the video height is greater than the video width
        if (videoHeight > videoWidth) {
          await _showPortraitModeErrorDialog();
          return false;
        }

        // Check for video aspect ratio before saving video.
        // In some videos, the DAP/SAP (display/sample aspect ratio) properties are not explicity defined which will cause ffprobe to return a null value,
        // so the workaround here uses the video width & height to determine the aspect ratio
        final num videoAspectRatio = (videoWidth / videoHeight).toPrecision(2);

        // 1.78 is the decimal equivalent of 16:9 aspect ratio videos
        if (videoAspectRatio != 1.78) {
          await _showAspectRatioErrorDialog();
          return false;
        }

        return true;
      }
      return false;
    });
  }

  Future<void> _showPortraitModeErrorDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        title: Text(
          'oops'.tr,
        ),
        content: Text(
          'unsupportedPortraitMode'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () async => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.green,
            ),
            child: Text('ok'.tr),
          )
        ],
      ),
    );
  }

  Future<void> _showAspectRatioErrorDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        title: Text(
          'oops'.tr,
        ),
        content: Text(
          'videoResolutionWarning'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () async => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.green,
            ),
            child: Text('ok'.tr),
          )
        ],
      ),
    );
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
              await File(currentVideo).delete();
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
              });

              await getSelectedDateThumbnail();

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
            childAspectRatio: 1.2,
            onDayPressed: (DateTime date, List<Event> events) async {
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
        const SizedBox(
          height: 10.0,
        ),
        Expanded(
          child: wasDateRecorded
              ? Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.25,
                      child: Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: FutureBuilder(
                          future: getThumbnail(currentVideo),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: SizedBox(
                                  height: 30,
                                  width: 30,
                                  child: CircularProgressIndicator(
                                    color: mainColor,
                                  ),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Text(
                                '${snapshot.error}',
                              );
                            }
                            return Image.memory(snapshot.data as Uint8List);
                          },
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
}
