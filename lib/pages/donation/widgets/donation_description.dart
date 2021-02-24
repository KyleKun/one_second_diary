import 'package:flutter/material.dart';

class DonationDescription extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Thank you so much for using the app!\n\nIf you wish to show your appreciation,\nfeel free to make a donation. ^^',
      style: TextStyle(fontSize: 18.0),
      textAlign: TextAlign.center,
    );
  }
}
