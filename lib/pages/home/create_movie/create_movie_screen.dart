import 'package:flutter/material.dart';
import 'widgets/create_movie_button.dart';
import 'widgets/video_count_card.dart';
import 'package:get/get.dart';

class CreateMoviePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        SizedBox(),
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
        CreateMovieButton(),
        SizedBox(),
      ],
    );
  }
}
