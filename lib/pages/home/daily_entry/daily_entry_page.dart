import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/daily_entry_controller.dart';
import 'package:one_second_diary/pages/home/daily_entry/widgets/emoji_widget.dart';

import 'widgets/edit_daily_button.dart';
import 'widgets/record_daily_button.dart';

class AddNewRecordingPage extends GetView<DailyEntryController> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.7,
      //TODO: needs testing
      child: Obx(
        () => Container(
          child: controller.dailyEntry.value
              ? _dailyComplete()
              : _dailyIncomplete(),
        ),
      ),
    );
  }

  Widget _dailyComplete() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        EmojiWidget(complete: true),
        EditDailyButton(),
      ],
    );
  }

  Widget _dailyIncomplete() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        EmojiWidget(complete: false),
        RecordDailyButton(),
      ],
    );
  }
}
