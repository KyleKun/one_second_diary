import 'package:flutter/material.dart';

class CreateMovieScreen extends StatefulWidget {
  @override
  _CreateMovieScreenState createState() => _CreateMovieScreenState();
}

class _CreateMovieScreenState extends State<CreateMovieScreen> {
  //TODO: replace by the actual variable from hive
  int numberOfVideos = 12;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            'You have currently\n\n$numberOfVideos\n\nvideos recorded.',
            style: TextStyle(fontSize: 26.0),
            textAlign: TextAlign.center,
          ),
          Text(
            'Tap the button below to generate\na single video file:',
            style: TextStyle(fontSize: 18.0),
            textAlign: TextAlign.center,
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            height: MediaQuery.of(context).size.width * 0.15,
            child: RaisedButton(
              elevation: 5.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(80.0)),
              color: Colors.greenAccent,
              onPressed: () {
                print('create movie');
              },
              child: Text(
                'Create',
                style: TextStyle(color: Colors.white, fontSize: 22.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
