import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:shimmer/shimmer.dart';

class CreateMovieScreen extends StatefulWidget {
  @override
  _CreateMovieScreenState createState() => _CreateMovieScreenState();
}

class _CreateMovieScreenState extends State<CreateMovieScreen> {
  //TODO: replace by the actual variable from hive
  int numberOfVideos = 1207;
  int totalEstimatedTime = 1;

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
          FlipCard(
            direction: FlipDirection.VERTICAL, // default
            front: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xffff6366),
                        Color(0xffff6366).withOpacity(0.85),
                        Color(0xffff6366).withOpacity(0.6)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    // border: Border.all(
                    //   color: Color(0xff7CEA9C),
                    //   width: 3.5,
                    // ),
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: MediaQuery.of(context).size.width * 0.3,
                  child: Center(
                    child: Shimmer.fromColors(
                      period: Duration(milliseconds: 450),
                      loop: 2,
                      baseColor: Colors.white,
                      highlightColor: Colors.amberAccent,
                      child: Text(
                        '$numberOfVideos days.',
                        style: TextStyle(color: Colors.white, fontSize: 36.0),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10.0,
                  right: 10.0,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.08,
                    height: MediaQuery.of(context).size.width * 0.08,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber[600],
                      border: Border.all(color: Colors.white, width: 2.0),
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      size: 20.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            back: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xffff6366),
                        Color(0xffff6366).withOpacity(0.85),
                        Color(0xffff6366).withOpacity(0.6)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    // border: Border.all(
                    //   color: Colors.amber,
                    //   width: 3.5,
                    // ),
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: MediaQuery.of(context).size.width * 0.3,
                  child: Center(
                    child: Text(
                      'Total time: ~ $totalEstimatedTime min.',
                      style: TextStyle(color: Colors.white, fontSize: 22.0),
                    ),
                  ),
                ),
                Positioned(
                  top: 10.0,
                  right: 10.0,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.08,
                    height: MediaQuery.of(context).size.width * 0.08,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber[600],
                      border: Border.all(color: Colors.white, width: 2.0),
                    ),
                    child: Icon(
                      Icons.timer,
                      size: 20.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.1,
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
              color: Colors.amber[600],
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
