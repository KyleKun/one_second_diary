import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';

class IntroPage extends StatelessWidget {
  final introKey = GlobalKey<IntroductionScreenState>();

  void _onIntroEnd() async {
    await StorageUtil.putBool('showIntro', false);
    await StorageUtil.putBool('dailyEntry', false);
    await StorageUtil.putInt('videoCount', 0);
    Get.offNamed(Routes.HOME);
  }

  Widget _buildImage(String assetName) {
    return Align(
      child: Image.asset('assets/images/$assetName.png', width: 350.0),
      alignment: Alignment.bottomCenter,
    );
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 19.0);
    const pageDecoration = const PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: bodyStyle,
      descriptionPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      key: introKey,
      pages: [
        PageViewModel(
          title: "Record 1 second everyday",
          body:
              "Choose a special moment of your day that you would like to remember in the future.",
          image: _buildImage('intro1'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Create the movie of your life",
          body: "Generate a compilation of all your recorded videos.",
          image: _buildImage('intro2'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "No Ads and Totally Free",
          body:
              "If you like the app, consider supporting the development with a donation.",
          image: _buildImage('intro3'),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(),
      showSkipButton: true,
      skipFlex: 0,
      nextFlex: 0,
      skip: const Text('Skip'),
      next: const Icon(Icons.arrow_forward),
      done: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        activeColor: AppColors.mainColor,
        color: AppColors.rose,
        activeSize: Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
    );
  }
}
