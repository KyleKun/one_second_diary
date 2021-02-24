import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/video_count_controller.dart';
import 'package:one_second_diary/utils/constants.dart';

class VideoCountCard extends GetView<VideoCountController> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      height: MediaQuery.of(context).size.width * 0.3,
      child: Card(
        elevation: 10.0,
        color: AppColors.mainColor,
        child: Stack(
          children: [
            Center(
              child: Obx(
                () => Text(
                  '${controller.videoCount} days.',
                  style: TextStyle(color: Colors.white, fontSize: 36.0),
                ),
              ),
            ),
            Positioned(
              top: 10.0,
              right: 10.0,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.07,
                height: MediaQuery.of(context).size.width * 0.07,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(
                  Icons.emoji_events,
                  size: 20.0,
                  color: AppColors.mainColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
