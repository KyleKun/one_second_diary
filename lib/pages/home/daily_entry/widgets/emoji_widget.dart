import 'package:flutter/material.dart';

class EmojiWidget extends StatelessWidget {
  EmojiWidget({this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          complete
              ? 'Amazing!\nSee you tomorrow!'
              : 'Waiting for\nyour recording...',
          style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.065),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.05),
        Image.asset(
          complete
              ? 'assets/images/confirmed.png'
              : 'assets/images/waiting.png',
          width: MediaQuery.of(context).size.width * 0.5,
        ),
      ],
    );
  }
}
