import 'package:flutter/material.dart';

class EmojiWidget extends StatelessWidget {
  EmojiWidget({this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.5,
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          fit: BoxFit.contain,
          image: AssetImage(
            complete
                ? 'assets/images/confirmed.png'
                : 'assets/images/waiting.png',
          ),
        ),
      ),
      child: Text(
        complete
            ? 'Amazing!\nSee you tomorrow!'
            : 'Waiting for\nyour recording...',
        style: TextStyle(fontSize: 22.0),
        textAlign: TextAlign.center,
      ),
    );
  }
}
