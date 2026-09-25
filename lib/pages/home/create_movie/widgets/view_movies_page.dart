import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../utils/app_paths.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/delete_confirmation_dialog.dart';
import '../../../../utils/media_gallery.dart';
import '../../../../utils/storage_utils.dart';
import '../../../../utils/theme.dart';
import '../../../../utils/utils.dart';

class ViewMovies extends StatefulWidget {
  const ViewMovies({super.key});

  @override
  State<ViewMovies> createState() => _ViewMoviesState();
}

class _ViewMoviesState extends State<ViewMovies> {
  List<String>? allMovies;

  // One thumbnail request per movie, started the first time its card is
  // built and reused afterwards — so scrolling back, or deleting another
  // movie, never regenerates thumbnails that already exist.
  final Map<String, Future<Uint8List?>> _thumbnails = {};

  late final bool isDarkTheme = ThemeService().isDarkTheme();

  @override
  void initState() {
    super.initState();
    allMovies = Utils.getAllMovies(fullPath: true);
  }

  Future<Uint8List?> _thumbnailFor(String movie) {
    return _thumbnails.putIfAbsent(movie, () async {
      try {
        return await VideoThumbnail.thumbnailData(
          video: File(movie).path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 720,
          quality: 60,
        );
      } catch (e) {
        Utils.logError('[MOVIES VIEWER] - Thumbnail failed for $movie: $e');
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('myMovies'.tr, style: const TextStyle(color: Colors.white)),
      ),
      body: allMovies == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.mainColor),
            )
          : allMovies!.isEmpty
          ? _EmptyMovies(isDarkTheme: isDarkTheme)
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: allMovies!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final String movie = allMovies![index];
                return _MovieCard(
                  key: ValueKey(movie),
                  filePath: movie,
                  thumbnail: _thumbnailFor(movie),
                  isDarkTheme: isDarkTheme,
                  onDelete: () => deleteVideoDialog(movie),
                );
              },
            ),
    );
  }

  Future<void> deleteVideoDialog(String videoFile) async {
    MediaGallery.instance.setAlbum('${AppPaths.folderName}/Movies');
    if (!await DeleteConfirmationDialog.show(context)) return;

    // Delete current video from storage
    await StorageUtils.deleteVideo(videoFile);

    Utils.logInfo('[MOVIES VIEWER] - Deleted movie $videoFile');

    // Refresh the UI
    if (mounted) {
      setState(() {
        allMovies!.removeWhere((element) => element == videoFile);
        _thumbnails.remove(videoFile);
      });
    }
  }
}

class _MovieCard extends StatelessWidget {
  const _MovieCard({
    super.key,
    required this.filePath,
    required this.thumbnail,
    required this.isDarkTheme,
    required this.onDelete,
  });

  final String filePath;
  final Future<Uint8List?> thumbnail;
  final bool isDarkTheme;
  final VoidCallback onDelete;

  String get _fileName => filePath.split('/').last;

  String get _title {
    final String name = _fileName;
    final int dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String? get _fileSize {
    try {
      final int bytes = File(filePath).lengthSync();
      if (bytes >= 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }
      if (bytes >= 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / 1024).ceil()} KB';
    } catch (_) {
      return null;
    }
  }

  Future<void> _play() async => await OpenFilex.open(filePath);

  void _share() {
    SharePlus.instance.share(ShareParams(files: [XFile(filePath)]));
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDarkTheme ? Colors.white : AppColors.dark;
    final Color mutedTextColor = isDarkTheme ? Colors.white60 : Colors.black54;
    final Color cardColor = isDarkTheme
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final String? size = _fileSize;
    final String extension = _fileName.contains('.')
        ? _fileName.split('.').last.toUpperCase()
        : '';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail — tap to play
          GestureDetector(
            onTap: _play,
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder<Uint8List?>(
                      future: thumbnail,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white54,
                              ),
                            ),
                          );
                        }
                        final Uint8List? bytes = snapshot.data;
                        if (bytes == null) {
                          return const Center(
                            child: Icon(
                              Icons.movie_outlined,
                              color: Colors.white38,
                              size: 48,
                            ),
                          );
                        }
                        // Contain, not cover: portrait movies are shown
                        // whole (pillarboxed) instead of cropped.
                        return Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        );
                      },
                    ),
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Info + actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    extension,
                    if (size != null) size,
                  ].where((part) => part.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 13, color: mutedTextColor),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'play'.tr,
                        foreground: Colors.white,
                        background: AppColors.mainColor,
                        onPressed: _play,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.share_rounded,
                        label: 'share'.tr,
                        foreground: textColor,
                        background: isDarkTheme
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.06),
                        onPressed: _share,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: IconButton(
                        onPressed: onDelete,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMovies extends StatelessWidget {
  const _EmptyMovies({required this.isDarkTheme});

  final bool isDarkTheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.mainColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.movie_outlined,
                color: AppColors.mainColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'noMoviesFound'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDarkTheme ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
