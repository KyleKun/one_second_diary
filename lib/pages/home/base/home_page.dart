import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/bottom_app_bar_index_controller.dart';
import '../calendar_editor/calendar_editor_page.dart';
import '../create_movie/create_movie_screen.dart';
import '../daily_entry/daily_entry_page.dart';
import '../settings/settings_page.dart';
import 'widgets/app_bar.dart';
import 'widgets/bottom_app_bar.dart';

class HomePage extends GetView<BottomAppBarIndexController> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      bottomNavigationBar: CustomBottomAppBar(),
      resizeToAvoidBottomInset: false,
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Obx(() => _getSelectedPage(controller.activeIndex.value)),
      ),
    );
  }

  Widget _getSelectedPage(int index) {
    switch (index) {
      case 0:
        return DailyEntryPage();
      case 1:
        return const CalendarEditorPage();
      case 2:
        return CreateMoviePage();
      case 3:
        return SettingPage();
      default:
        return DailyEntryPage();
    }
  }
}
