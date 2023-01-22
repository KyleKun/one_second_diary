import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  // ExportOrientation _orientationDefaultValue = ExportOrientation.landscape;

  // final List<ExportOrientation> _orientationValues = [
  //   ExportOrientation.portrait,
  //   ExportOrientation.landscape,
  // ];

  final dropdownBorder = OutlineInputBorder(
    borderSide: BorderSide(
      color: ThemeService().isDarkTheme() ? Colors.black : Colors.white,
      width: 2,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final selectedVideos =
        Utils.getSelectedVideosFromStorage(_exportPeriodGroupValue);

    String getClipsFound() {
      return selectedVideos.length.toString();
    }

    return WillPopScope(
      onWillPop: () async {
        showDialog(
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
        return true;
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
                          child: DropdownButtonFormField<ExportDateRange>(
                            value: _exportPeriodGroupValue,
                            icon: const Icon(Icons.expand_more),
                            iconSize: 24,
                            elevation: 16,
                            borderRadius: BorderRadius.circular(12),
                            isExpanded: true,
                            dropdownColor: ThemeService().isDarkTheme()
                                ? AppColors.dark
                                : AppColors.light,
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
                                // await selectVideosFromStorage();
                                Get.toNamed(Routes.SELECT_VIDEOS_FROM_STORAGE);
                              }
                            },
                            items: _exportPeriods
                                .map<DropdownMenuItem<ExportDateRange>>(
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
                    )
                  ],
                ),

                SizedBox(height: MediaQuery.of(context).size.height * 0.025),

                const Spacer(),
                if (_exportPeriodGroupValue != ExportDateRange.custom)
                  Text(
                    '${'clipsFound'.tr}: ${getClipsFound()}',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.060,
                    ),
                  ),
                const Spacer(),
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
                  // selectedOrientation: _orientationDefaultValue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
