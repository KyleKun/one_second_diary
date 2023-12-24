import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../controllers/video_count_controller.dart';
import '../../../../enums/export_date_range.dart';
// import '../../../../enums/export_orientations.dart';
import '../../../../routes/app_pages.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/custom_dialog.dart';
import '../../../../utils/theme.dart';
import '../../../../utils/utils.dart';
import 'create_movie_button.dart';

class CreateMovieOptions extends StatefulWidget {
  const CreateMovieOptions({super.key});

  @override
  State<CreateMovieOptions> createState() => _CreateMovieOptionsState();
}

class _CreateMovieOptionsState extends State<CreateMovieOptions> {
  ExportDateRange _exportPeriodGroupValue = ExportDateRange.allTime;
  final List<ExportDateRange> _exportPeriods = ExportDateRange.values;
  final VideoCountController controller = Get.find();

  final dropdownBorder = OutlineInputBorder(
    borderSide: BorderSide(
      color: ThemeService().isDarkTheme() ? Colors.black : Colors.white,
      width: 2,
    ),
  );

  List<String>? selectedVideos;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        selectedVideos = Utils.getSelectedVideosFromStorage(_exportPeriodGroupValue);
      });
    });
  }

  String getClipsFound() {
    return selectedVideos!.length.toString();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) async {
        await showDialog(
          barrierDismissible: false,
          context: Get.context!,
          builder: (context) => CustomDialog(
            isDoubleAction: true,
            title: 'cancelMovieCreation'.tr,
            content: 'cancelMovieDesc'.tr,
            actionText: 'yes'.tr,
            actionColor: AppColors.green,
            action: () => Get.offAllNamed(Routes.HOME),
            action2Text: 'no'.tr,
            action2Color: Colors.red,
            action2: () => Get.back(),
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'createMovie'.tr,
            style: TextStyle(
              fontFamily: 'Magic',
              fontSize: MediaQuery.of(context).size.width * 0.05,
            ),
          ),
        ),
        body: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Date range
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: MediaQuery.of(context).size.height * 0.025,
                        bottom: MediaQuery.of(context).size.height * 0.01,
                      ),
                      child: Text(
                        'dateRange'.tr,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.height * 0.025,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: MediaQuery.of(context).size.height * 0.025,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 300,
                          child: Obx(
                            () => IgnorePointer(
                              ignoring: controller.isProcessing.value,
                              child: DropdownButtonFormField<ExportDateRange>(
                                value: _exportPeriodGroupValue,
                                icon: const Icon(Icons.expand_more),
                                iconSize: 24,
                                elevation: 16,
                                borderRadius: BorderRadius.circular(12),
                                isExpanded: true,
                                dropdownColor:
                                    ThemeService().isDarkTheme() ? AppColors.dark : AppColors.light,
                                decoration: InputDecoration(
                                  enabledBorder: dropdownBorder,
                                  focusedBorder: dropdownBorder,
                                  border: dropdownBorder,
                                  filled: true,
                                  fillColor: ThemeService().isDarkTheme()
                                      ? AppColors.dark
                                      : AppColors.light,
                                ),
                                onChanged: (newValue) async {
                                  setState(() {
                                    _exportPeriodGroupValue = newValue!;
                                  });

                                  if (newValue == ExportDateRange.custom) {
                                    // Needs more than 1 video to create movie
                                    if (selectedVideos!.length < 2) {
                                      showDialog(
                                        barrierDismissible: false,
                                        context: Get.context!,
                                        builder: (context) => CustomDialog(
                                          isDoubleAction: false,
                                          title: 'movieErrorTitle'.tr,
                                          content: 'movieInsufficientVideos'.tr,
                                          actionText: 'Ok',
                                          actionColor: AppColors.green,
                                          action: () => Get.back(),
                                        ),
                                      );
                                      return;
                                    }
                                    Get.toNamed(
                                      Routes.SELECT_VIDEOS_FROM_STORAGE,
                                    );
                                    return;
                                  }
                                  // To show loading
                                  setState(() {
                                    selectedVideos = null;
                                  });
                                  // Update values
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    setState(() {
                                      selectedVideos = Utils.getSelectedVideosFromStorage(
                                        _exportPeriodGroupValue,
                                      );
                                    });
                                  });
                                },
                                items: _exportPeriods.map<DropdownMenuItem<ExportDateRange>>(
                                  (ExportDateRange value) {
                                    return DropdownMenuItem<ExportDateRange>(
                                      value: value,
                                      child: Text(value.localizationLabel.tr),
                                    );
                                  },
                                ).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),

                SizedBox(height: MediaQuery.of(context).size.height * 0.025),

                const Spacer(),

                if (selectedVideos != null && _exportPeriodGroupValue != ExportDateRange.custom)
                  Text(
                    '${'clipsFound'.tr}: ${getClipsFound()}',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.060,
                    ),
                  )
                else if (_exportPeriodGroupValue != ExportDateRange.custom)
                  const Icon(
                    Icons.hourglass_bottom,
                    size: 32.0,
                  ),
                const Spacer(),
                if (selectedVideos != null && _exportPeriodGroupValue != ExportDateRange.custom)
                  Column(
                    children: [
                      Text(
                        'tapBelowToGenerate'.tr,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20.0),
                      CreateMovieButton(
                        selectedExportDateRange: _exportPeriodGroupValue,
                      )
                    ],
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
