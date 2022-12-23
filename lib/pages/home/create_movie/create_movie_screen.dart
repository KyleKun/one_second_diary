import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../utils/constants.dart';
import 'widgets/video_count_card.dart';

class CreateMoviePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        const SizedBox(),
        Text(
          'totalRecordedTitle'.tr,
          style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.07),
          textAlign: TextAlign.center,
        ),
        VideoCountCard(),
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        Text(
          'tapBelowToGenerate'.tr,
          style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.045),
          textAlign: TextAlign.center,
        ),
        const _CreateMovieOptionsButton(),
        const SizedBox(),
      ],
    );
  }
}

class _CreateMovieOptionsButton extends StatelessWidget {
  const _CreateMovieOptionsButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      height: MediaQuery.of(context).size.height * 0.08,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mainColor,
          elevation: 5.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(80.0),
          ),
        ),
        onPressed: () async => await Get.toNamed(Routes.CREATE_MOVIE_OPTIONS),
        child: Text(
          'create'.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width * 0.055,
          ),
        ),
      ),
    );
  }
}
