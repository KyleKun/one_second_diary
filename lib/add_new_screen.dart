import 'package:flutter/material.dart';

class AddNewScreen extends StatefulWidget {
  @override
  _AddNewScreenState createState() => _AddNewScreenState();
}

class _AddNewScreenState extends State<AddNewScreen> {
  //TODO: replace by the actual variable from hive
  bool recordedToday = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                fit: BoxFit.contain,
                image: AssetImage(
                  recordedToday
                      ? 'assets/images/confirmed.png'
                      : 'assets/images/waiting.png',
                ),
              ),
            ),
            child: Text(
              recordedToday
                  ? 'Good job! See ya tomorrow ;)'
                  : 'Waiting today\'s recording...',
              style: TextStyle(fontSize: 22.0),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            height: MediaQuery.of(context).size.width * 0.15,
            child: RaisedButton(
              elevation: 5.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(80.0)),
              color: recordedToday ? Colors.orangeAccent : Colors.greenAccent,
              onPressed: () {
                setState(() {
                  //TODO: push record screen
                  recordedToday = !recordedToday;
                });
              },
              child: Text(
                recordedToday ? 'Edit' : 'Record',
                style: TextStyle(color: Colors.white, fontSize: 22.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
