import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart'
    show CalendarCarousel;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../controllers/lang_controller.dart';
import '../../../controllers/video_count_controller.dart';
import '../../../routes/app_pages.dart';
import '../../../utils/constants.dart';
import '../../../utils/date_format_utils.dart';
import '../../../utils/ffmpeg_api_wrapper.dart';
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
  late String? subtitles;
  String currentVideo = '';
  bool wasDateRecorded = false;
  DateTime _currentDate = DateTime.now();
  late Color mainColor;
  final String _currentDateStr = DateFormatUtils.getToday();
  final LanguageController _languageController = Get.find();

  @override
  void initState() {
    mainColor = ThemeService().isDarkTheme() ? Colors.white : Colors.black;
    allVideos = Utils.getAllVideos(fullPath: true);
    getTodaysThumbnail();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void getTodaysThumbnail() {
    setState(() {
      wasDateRecorded = allVideos.any((a) => a.contains(_currentDateStr));
      if (wasDateRecorded) {
        currentVideo = allVideos.firstWhere(
          (a) => a.contains(_currentDateStr),
        );
      }
    });
  }

  void getCurrentDateThumbnail() {
    final parsedCurrentDate = DateFormatUtils.getDate(_currentDate);
    setState(() {
      wasDateRecorded = allVideos.any((a) => a.contains(parsedCurrentDate));
      if (wasDateRecorded) {
        currentVideo = allVideos.firstWhere(
          (a) => a.contains(parsedCurrentDate),
        );
      }
    });
  }

  Future<Uint8List?> getThumbnail(String video) async {
    final thumbnail = await VideoThumbnail.thumbnailData(
      video: File(video).path,
      imageFormat: ImageFormat.JPEG,
      quality: 15,
    );
    return thumbnail;
  }

  Future<void> selectVideoFromGallery() async {
    final rawFile = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );

    if (rawFile != null) {
      // Go to the save video page
      Get.toNamed(
        Routes.SAVE_VIDEO,
        arguments: {
          'videoPath': rawFile.path,
          'currentDate': _currentDate,
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
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: ThemeService().isDarkTheme() ? AppColors.light : AppColors.dark,
            ),
            child: Text('no'.tr),
          ),
          TextButton(
            onPressed: () async {
              // Delete current video from storage
              await File(currentVideo).delete();

              // Reduce the video count recorded by the app
              VideoCountController().reduceVideoCount();

              // Refresh the UI
              setState(() {
                allVideos = Utils.getAllVideos(fullPath: true);
                getCurrentDateThumbnail();
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
            childAspectRatio: 1.2,
            onDayPressed: (DateTime date, List<Event> events) {
              setState(
                () => _currentDate = date,
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
            iconColor: ThemeService().isDarkTheme() ? Colors.white : Colors.black,
            headerTextStyle: TextStyle(
              fontFamily: 'Magic',
              fontSize: 20.0,
              color: mainColor,
            ),
            locale: _languageController.selectedLanguage.value,
            shouldShowTransform: false,
            height: MediaQuery.of(context).size.height * 0.42,
            showOnlyCurrentMonthDate: true,
            selectedDateTime: _currentDate,
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
                            if (snapshot.connectionState == ConnectionState.waiting) {
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30.0),
                              ),
                            ),
                            onPressed: () async {
                              final Directory directory =
                                  await getApplicationDocumentsDirectory();
                              final String srtPath = '${directory.path}/temp.srt';
                              final getSubsFile =
                                  await executeFFmpeg('-i $currentVideo $srtPath -y');
                              final resultCode = await getSubsFile.getReturnCode();
                              if (ReturnCode.isSuccess(resultCode)) {
                                final srtFile = await File(srtPath).readAsString();
                                setState(() {
                                  subtitles = srtFile.trim().split(',000').last;
                                });
                              } else {
                                setState(() {
                                  subtitles = null;
                                });
                              }
                              Get.to(
                                VideoSubtitlesEditorPage(
                                  videoPath: currentVideo,
                                  subtitles: subtitles,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                'editSubtitles'.tr,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await deleteVideoDialog();
                            },
                            icon: const Icon(
                              Icons.delete,
                              color: AppColors.mainColor,
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
                    if (!_currentDate.isAfter(DateTime.now()))
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mainColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30.0),
                            ),
                          ),
                          onPressed: () async {
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
