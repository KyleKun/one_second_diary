import 'package:flutter/material.dart';
import 'package:one_second_diary/pages/donation/widgets/donate_button.dart';
import 'package:one_second_diary/pages/donation/widgets/donation_description.dart';
import 'package:one_second_diary/pages/donation/widgets/heart_animation.dart';

class DonationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Support app development'),
      ),
      body: Column(
        children: [
          HeartAnimation(),
          DonationDescription(),
          Spacer(),
          DonateButton(),
          Spacer(flex: 2),
        ],
      ),
    );
  }
}
