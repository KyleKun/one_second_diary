import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../utils/constants.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/lazy_future_builder.dart';
import '../../../../utils/utils.dart';
import 'create_movie_button.dart';

class SelectVideoFromStorage extends StatefulWidget {
  const SelectVideoFromStorage({super.key});

  @override
  State<SelectVideoFromStorage> createState() => _SelectVideoFromStorageState();
}

class _SelectVideoFromStorageState extends State<SelectVideoFromStorage> {
  List<String>? allVideos;
  List<bool>? isSelected;
  List<GlobalKey>? globalKeys;
  Map<String, Uint8List?> thumbnails = {};
  final ScrollController scrollController = ScrollController();
  IconData selectIcon = Icons.select_all;
  IconData navigationIcon = Icons.arrow_downward;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 250), () {
      allVideos = Utils.getAllVideos(fullPath: true);
      isSelected = List.filled(allVideos!.length, false);
      globalKeys = List.generate(allVideos!.length, (index) => GlobalKey());
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // Count all true in isSelected and return quantity
    final int totalSelected = isSelected?.where((element) => element).length ?? 0;
    final aspectRatio = allVideos?.first.contains('_vertical') == true ? 0.5 : 1.0;
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          'selectVideos'.tr,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(navigationIcon),
            onPressed: () {
              if (allVideos == null) return;
              if (navigationIcon == Icons.arrow_downward) {
                scrollController.jumpTo(
                  scrollController.position.maxScrollExtent,
                );
                setState(() {
                  navigationIcon = Icons.arrow_upward;
                });
              } else {
                scrollController.jumpTo(
                  scrollController.position.minScrollExtent,
                );
                setState(() {
                  navigationIcon = Icons.arrow_downward;
                });
              }
            },
          ),
          IconButton(
            icon: Icon(selectIcon),
            onPressed: () {
              if (allVideos == null) return;
              if (selectIcon == Icons.select_all) {
                setState(() {
                  isSelected = List.filled(allVideos!.length, true);
                  selectIcon = Icons.deselect;
                });
              } else {
                setState(() {
                  isSelected = List.filled(allVideos!.length, false);
                  selectIcon = Icons.select_all;
                });
              }
            },
          ),
        ],
      ),
      body: allVideos == null
          ? const Center(
              child: Icon(
                Icons.hourglass_bottom,
                size: 32.0,
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    '${'totalSelected'.tr}$totalSelected',
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    addAutomaticKeepAlives: true,
                    cacheExtent: 99999,
                    shrinkWrap: true,
                    controller: scrollController,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: aspectRatio,
                    ),
                    itemCount: allVideos!.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          Text(
                            DateFormatUtils.parseDateStringAccordingLocale(
                              allVideos![index].split('/').last.split('.mp4').first,
                            ),
                            key: globalKeys![index],
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                isSelected![index] = !isSelected![index];
                              });
                              if (isSelected![index] && index != allVideos!.length - 1) {
                                scrollController.position.ensureVisible(
                                  globalKeys![index + 1].currentContext!.findRenderObject()!,
                                  duration: const Duration(milliseconds: 750),
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.all(15.0),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected![index] ? AppColors.green : Colors.white,
                                  width: isSelected![index] ? 4 : 1,
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: LazyFutureBuilder(
                                future: () => getThumbnail(allVideos![index]),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(
                                      child: SizedBox(
                                        height: 30,
                                        width: 30,
                                        child: Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return Text(
                                      '${snapshot.error}',
                                    );
                                  }
                                  return Image.memory(
                                    snapshot.data as Uint8List,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (totalSelected >= 2) ...{
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: CreateMovieButton(
                      customSelectedVideos: allVideos,
                      customSelectedVideosIsSelected: isSelected,
                    ),
                  ),
                }
              ],
            ),
    );
  }

  Future<Uint8List?> getThumbnail(String video) async {
    if (thumbnails.containsKey(video)) {
      return thumbnails[video];
    }
    final thumbnail = await VideoThumbnail.thumbnailData(
      video: File(video).path,
      imageFormat: ImageFormat.JPEG,
      quality: 8,
    );
    setState(() {
      thumbnails[video] = thumbnail;
    });
    return thumbnail;
  }
}
