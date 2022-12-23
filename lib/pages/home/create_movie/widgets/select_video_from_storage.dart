import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../../../utils/utils.dart';
import 'create_movie_button.dart';

class SelectVideoFromStorage extends StatefulWidget {
  const SelectVideoFromStorage({super.key});

  @override
  State<SelectVideoFromStorage> createState() => _SelectVideoFromStorageState();
}

class _SelectVideoFromStorageState extends State<SelectVideoFromStorage> {
  late List<String> allVideos;
  late List<bool> isSelected;
  late List<GlobalKey> globalKeys;
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    allVideos = Utils.getAllVideos(fullPath: true);
    isSelected = List.filled(allVideos.length, false);
    globalKeys = List.generate(allVideos.length, (index) => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
    // Count all true in isSelected and return quantity
    final int totalSelected = isSelected.where((element) => element).length;
    return Material(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.all(20.0),
            // TODO: translate
            child: Text(
              'Tap on a video to select it. Total selected: $totalSelected',
            ),
          ),
          Expanded(
            child: GridView.builder(
              cacheExtent: 100,
              shrinkWrap: true,
              controller: scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
              ),
              itemCount: allVideos.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Text(
                      allVideos[index].split('/').last.split('.mp4')[0],
                      key: globalKeys[index],
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isSelected[index] = !isSelected[index];
                        });
                        if (isSelected[index] &&
                            index != allVideos.length - 1) {
                          scrollController.position.ensureVisible(
                            globalKeys[index + 1]
                                .currentContext!
                                .findRenderObject()!,
                            duration: const Duration(milliseconds: 750),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(15.0),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                isSelected[index] ? Colors.green : Colors.white,
                            width: 5,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: FutureBuilder(
                          future: getThumbnail(allVideos[index]),
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
                              // TODO: translate
                              return Text(
                                'An error occured: ${snapshot.error}',
                              );
                            }
                            return Image.memory(snapshot.data as Uint8List);
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
    return await VideoThumbnail.thumbnailData(
      video: File(video).path,
      imageFormat: ImageFormat.JPEG,
    );
  }
}
