import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../../enums/video_orientation.dart';
import '../../routes/app_pages.dart';
import '../../utils/constants.dart';
import '../../utils/shared_preferences_util.dart';
import '../../utils/storage_utils.dart';
import '../../utils/utils.dart';

class IntroPage extends StatelessWidget {
  IntroPage({Key? key}) : super(key: key);

  final introKey = GlobalKey<IntroductionScreenState>();

  // Guards against a second tap on "done" while the awaits below (the
  // storage permission prompt in particular) are still running. Static
  // because this widget is stateless; the page is left for good once
  // _onIntroEnd finishes, so it never needs resetting.
  static bool _isEnding = false;

  Future<void> _onIntroEnd() async {
    if (_isEnding) return;
    _isEnding = true;

    await SharedPrefsUtil.putString('appPath', '');
    await SharedPrefsUtil.putString('moviesPath', '');
    await SharedPrefsUtil.putInt('videoCount', 0);
    await SharedPrefsUtil.putInt('movieCount', 1);

    // A reinstall (or cleared app data) lands here with the previous
    // install's clips still on disk. Those were all recorded while the app
    // was landscape-only, so the Default profile stays landscape instead of
    // offering a choice that would mismatch every existing clip.
    if (await StorageUtils.hasExistingVideos()) {
      await StorageUtils.createDefaultProfile(VideoOrientation.landscape);
      // Same count the "days recorded" card's refresh tap does. Storage
      // permission was already asked for by hasExistingVideos, so the old
      // clips are visible; VideoCountController reads this when HOME opens.
      await SharedPrefsUtil.putInt('videoCount', Utils.getAllVideos().length);
      await SharedPrefsUtil.putBool('showIntro', false);
      Get.offNamed(Routes.HOME);
      return;
    }

    // showIntro deliberately isn't set here — OnboardingOrientationPage
    // sets it, only once the Default profile actually exists. If the app
    // is killed before that finishes, showIntro is still unset next
    // launch, so getInitialRoute (main.dart) sends the user back through
    // the intro carousel and this page again instead of leaving them with
    // no profile and no way to ever be re-prompted.
    Get.offNamed(Routes.ONBOARDING_ORIENTATION);
  }

  Widget _buildImage(String assetName) {
    return Align(
      child: Image.asset('assets/images/$assetName.png', width: 350.0),
      alignment: Alignment.bottomCenter,
    );
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 19.0, color: Colors.black);
    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
      bodyTextStyle: bodyStyle,
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      key: introKey,
      globalBackgroundColor: Colors.white,
      pages: [
        PageViewModel(
          title: 'introTitle1'.tr,
          body: 'introDesc1'.tr,
          image: _buildImage('intro1'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'introTitle2'.tr,
          body: 'introDesc2'.tr,
          image: _buildImage('intro2'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'introTitle3'.tr,
          body: 'introDesc3'.tr,
          image: _buildImage('intro3'),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(),
      showSkipButton: true,
      dotsFlex: 0,
      nextFlex: 0,
      skip: Text('skip'.tr, style: const TextStyle(color: Colors.black)),
      next: const Icon(Icons.arrow_forward, color: Colors.black),
      done: Text(
        'done'.tr,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      dotsContainerDecorator: const BoxDecoration(color: Colors.white),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        activeColor: AppColors.mainColor,
        color: AppColors.rose,
        activeSize: Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
      baseBtnStyle: ButtonStyle(
        overlayColor: WidgetStateProperty.all(AppColors.rose),
      ),
    );
  }
}
