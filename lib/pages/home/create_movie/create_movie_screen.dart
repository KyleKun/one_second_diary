import 'package:flutter/material.dart';
import 'widgets/create_movie_button.dart';
import 'widgets/video_count_card.dart';

class CreateMoviePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            'You have recorded:',
            style: TextStyle(fontSize: 26.0),
            textAlign: TextAlign.center,
          ),
          VideoCountCard(),
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          Text(
            'Tap the button below to generate\na single video file:',
            style: TextStyle(fontSize: 18.0),
            textAlign: TextAlign.center,
          ),
          CreateMovieButton(),
        ],
      ),
    );
  }
}
