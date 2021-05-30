import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/daily_entry_controller.dart';
import 'widgets/edit_daily_button.dart';
import 'widgets/emoji_widget.dart';
import 'widgets/record_daily_button.dart';

class DailyEntryPage extends GetView<DailyEntryController> {
  @override
  Widget build(BuildContext context) {
    return Obx(
      () =>
          controller.dailyEntry.value! ? _dailyComplete() : _dailyIncomplete(),
    );
  }

  Widget _dailyComplete() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        EmojiWidget(complete: true),
        EditDailyButton(),
      ],
    );
  }

  Widget _dailyIncomplete() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        EmojiWidget(complete: false),
        RecordDailyButton(),
      ],
    );
  }
}
