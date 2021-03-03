import 'package:flutter/material.dart';
import 'widgets/create_movie_button.dart';
import 'widgets/video_count_card.dart';

class CreateMoviePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        SizedBox(),
        Text(
          'You have recorded:',
          style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.07),
          textAlign: TextAlign.center,
        ),
        VideoCountCard(),
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        Text(
          'Tap the button below to generate\na single video file:',
          style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.045),
          textAlign: TextAlign.center,
        ),
        CreateMovieButton(),
        SizedBox(),
      ],
    );
  }
}
