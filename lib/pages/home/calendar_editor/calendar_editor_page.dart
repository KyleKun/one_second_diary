import 'dart:io';

import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart'
    show CalendarCarousel;
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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
  final String _currentDateStr = DateFormatUtils.getToday(isDayFirst: false);

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

  Future<Uint8List?> getThumbnail(String video) async {
    final thumbnail = await VideoThumbnail.thumbnailData(
      video: File(video).path,
      imageFormat: ImageFormat.JPEG,
      quality: 15,
    );
    return thumbnail;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const Text('Select a day to add or edit a video'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            child: CalendarCarousel<Event>(
              onDayPressed: (DateTime date, List<Event> events) {
                setState(
                  () => _currentDate = date,
                );
                final currentVideoExists = allVideos.any(
                  (a) => a.contains(
                    DateFormatUtils.getDate(
                      date,
                      isDayFirst: false,
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
                          isDayFirst: false,
                        ),
                      ),
                    );
                  });
                  print(currentVideo);
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
                final hasVideo = allVideos.any(
                  (a) => a.contains(
                    DateFormatUtils.getDate(
                      date,
                      isDayFirst: false,
                    ),
                  ),
                );
                if (DateTime.now().compareTo(date) != -1) {
                  return Center(
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        color: hasVideo ? Colors.green : Colors.red,
                        fontFamily: 'Magic',
                      ),
                    ),
                  );
                } else {
                  return null;
                }
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
              nextDaysTextStyle: const TextStyle(
                color: Colors.grey,
                fontFamily: 'Magic',
              ),
              prevDaysTextStyle: const TextStyle(
                color: Colors.grey,
                fontFamily: 'Magic',
              ),
              weekdayTextStyle: const TextStyle(
                fontFamily: 'Magic',
              ),
              weekFormat: false,
              iconColor: ThemeService().isDarkTheme()
                  ? Colors.white
                  : Colors.black, // Color of icon
              headerTextStyle: TextStyle(
                fontSize: 20.0,
                color: mainColor,
              ),
              height: 350.0,
              selectedDateTime: _currentDate,
              daysHaveCircularBorder: true,
              daysTextStyle: TextStyle(
                fontFamily: 'Magic',
                color: mainColor,
              ),
            ),
          ),
          const SizedBox(
            height: 20.0,
          ),
          if (wasDateRecorded)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AspectRatio(
                    aspectRatio: 16 / 8,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: FutureBuilder(
                        future: getThumbnail(currentVideo),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: SizedBox(
                                height: 30,
                                width: 30,
                                child: CircularProgressIndicator(),
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
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      // Circle
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mainColor,
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
                        debugPrint(resultCode.toString());
                        if (ReturnCode.isSuccess(resultCode)) {
                          final srtFile = await File(srtPath).readAsString();
                          setState(() {
                            subtitles = srtFile.trim().split(',000').last;
                            print('srtFileContent -> $subtitles');
                          });
                        } else {
                          setState(() {
                            subtitles = null;
                          });
                          print('No subtitles found');
                        }
                        Get.to(
                          VideoSubtitlesEditorPage(
                            videoPath: currentVideo,
                            subtitles: subtitles,
                          ),
                        );
                      },
                      child: Text('editSubtitles'.tr),
                    ),
                  ),
                ),
              ],
            )
          else
            const Center(
              child: Text('No video recorded for this day'),
            ),
        ],
      ),
    );
  }
}
