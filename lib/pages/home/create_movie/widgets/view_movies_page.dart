import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../utils/constants.dart';
import '../../../../utils/lazy_future_builder.dart';
import '../../../../utils/theme.dart';
import '../../../../utils/utils.dart';

class ViewMovies extends StatefulWidget {
  const ViewMovies({super.key});

  @override
  State<ViewMovies> createState() => _ViewMoviesState();
}

class _ViewMoviesState extends State<ViewMovies> {
  List<String>? allMovies;
  Map<String, Uint8List?> thumbnails = {};
  final mediaStore = MediaStore();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 250), () {
      allMovies = Utils.getAllMovies(fullPath: true);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('myMovies'.tr),
      ),
      body: allMovies == null
          ? const Center(
              child: Icon(
                Icons.hourglass_bottom,
                size: 32.0,
              ),
            )
          : allMovies!.isEmpty
              ? Center(
                  child: Text(
                    'noMoviesFound'.tr,
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: 10),
                    Expanded(
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        addAutomaticKeepAlives: true,
                        cacheExtent: 99999,
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 1,
                        ),
                        itemCount: allMovies!.length,
                        itemBuilder: (context, index) {
                          final movie = allMovies![index];
                          return LazyFutureBuilder(
                            future: () => getThumbnail(movie),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
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
                              return Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        Align(
                                          alignment: Alignment.center,
                                          child: Image.memory(
                                            snapshot.data as Uint8List,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.topCenter,
                                          child: Container(
                                            height: 200,
                                            width: double.infinity,
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                end: Alignment(0.0, 0.6),
                                                begin: Alignment(0.0, -1),
                                                colors: <Color>[
                                                  Colors.black87,
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.topLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              allMovies![index].split('/').last,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11.0,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.topRight,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 22.0,
                                            ),
                                            onPressed: () {
                                              deleteVideoDialog(
                                                movie,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _ViewMoviesPlayButton(
                                          filePath: movie,
                                        ),
                                        _ViewMoviesShareButton(
                                          filePath: movie,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> deleteVideoDialog(String videoFile) async {
    MediaStore.appFolder = 'OneSecondDiary/Movies';
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
                fileName: videoFile.split('/').last,
                dirType: DirType.video,
                dirName: DirName.dcim,
              );

              Utils.logInfo('[MOVIES VIEWER] - Deleted movie $videoFile');

              // Refresh the UI
              setState(() {
                allMovies!.removeWhere((element) => element == videoFile);
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

  Future<Uint8List?> getThumbnail(String video) async {
    if (thumbnails.containsKey(video)) {
      return thumbnails[video];
    }
    final thumbnail = await VideoThumbnail.thumbnailData(
      video: File(video).path,
      imageFormat: ImageFormat.JPEG,
      quality: 15,
    );
    setState(() {
      thumbnails[video] = thumbnail;
    });
    return thumbnail;
  }
}

class _ViewMoviesShareButton extends StatelessWidget {
  const _ViewMoviesShareButton({required this.filePath});
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.055,
            minWidth: MediaQuery.of(context).size.width * 0.28,
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              elevation: 5.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(80.0),
              ),
            ),
            onPressed: () {
              Share.shareXFiles([XFile(filePath)]);
            },
            child: Text(
              'share'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: MediaQuery.of(context).size.height * 0.022,
              ),
            ),
          ),
        ),
        const Positioned(
          top: 0.0,
          left: 0.0,
          child: Icon(
            Icons.share_rounded,
            size: 20.0,
          ),
        )
      ],
    );
  }
}

class _ViewMoviesPlayButton extends StatelessWidget {
  const _ViewMoviesPlayButton({required this.filePath});
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.06,
            minWidth: MediaQuery.of(context).size.width * 0.40,
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              elevation: 5.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(80.0),
              ),
            ),
            onPressed: () async => await OpenFilex.open(filePath),
            child: Text(
              'play'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: MediaQuery.of(context).size.height * 0.022,
              ),
            ),
          ),
        ),
        const Positioned(
          top: 0.0,
          left: 0.0,
          child: Icon(
            Icons.play_circle,
            size: 20.0,
          ),
        )
      ],
    );
  }
}
