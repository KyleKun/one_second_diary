import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';
import '../../../utils/constants.dart';
import 'widgets/video_count_card.dart';

class CreateMoviePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                'totalRecordedTitle'.tr,
                style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.07),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),
              VideoCountCard(),
            ],
          ),
          const _CreateMovieOptionsButton(),
        ],
      ),
    );
  }
}

class _CreateMovieOptionsButton extends StatelessWidget {
  const _CreateMovieOptionsButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
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
          'createMovie'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width * 0.055,
          ),
        ),
      ),
    );
  }
}
