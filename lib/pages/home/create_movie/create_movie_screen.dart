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
                  fontSize: MediaQuery.of(context).size.width * 0.07,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.05,
              ),
              VideoCountCard(),
            ],
          ),
          Column(
            children: [
              const _CreateMovieOptionsButton(),
              const SizedBox(height: 10.0),
              const _ViewMoviesButton(),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateMovieOptionsButton extends StatelessWidget {
  const _CreateMovieOptionsButton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.07,
            minWidth: MediaQuery.of(context).size.width * 0.50,
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mainColor,
              elevation: 5.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(80.0),
              ),
            ),
            onPressed: () async {
              Get.toNamed(Routes.CREATE_MOVIE_OPTIONS);
            },
            child: Text(
              'createMovie'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: MediaQuery.of(context).size.width * 0.050,
              ),
            ),
          ),
        ),
        const Positioned(
          top: 0.0,
          left: 0.0,
          child: Icon(
            Icons.add_a_photo,
            size: 18.0,
          ),
        )
      ],
    );
  }
}

class _ViewMoviesButton extends StatelessWidget {
  const _ViewMoviesButton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.07,
            minWidth: MediaQuery.of(context).size.width * 0.50,
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              elevation: 5.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(80.0),
              ),
            ),
            onPressed: () => Get.toNamed(Routes.VIEW_MOVIES),
            child: Text(
              'myMovies'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: MediaQuery.of(context).size.width * 0.050,
              ),
            ),
          ),
        ),
        const Positioned(
          top: 0.0,
          left: 0.0,
          child: Icon(
            Icons.collections,
            size: 18.0,
          ),
        )
      ],
    );
  }
}
