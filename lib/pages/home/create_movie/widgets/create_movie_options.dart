import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../enums/export_date_range.dart';
import '../../../../utils/constants.dart';
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

  // String _orientationDefaultValue = 'Landscape';

  // final List<String> _orientationValues = [
  //   'Portrait',
  //   'Landscape',
  // ];

  // Stores the names of the manually selected videos
  List<String> customSelectedVideos = [];

  final dropdownBorder = OutlineInputBorder(
    borderSide: BorderSide(
      color: ThemeService().isDarkTheme() ? Colors.black : Colors.white,
      width: 2,
    ),
  );

  Future<void> selectVideosFromStorage() async {
    final rawFiles = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.video,
    );

    if (rawFiles != null) {
      // Splits the file names from the path before creating a new list
      setState(() {
        customSelectedVideos = rawFiles.paths.map((e) => e!.split('/file_picker/')[1]).toList()
          // Arrange the elements in the correct order
          ..sort(
            (a, b) => a.compareTo(b),
          );
      });
    }

    print('Custom selected videos are - > $customSelectedVideos');
  }

  @override
  Widget build(BuildContext context) {
    final selectedVideos = Utils.getSelectedVideosFromStorage(_exportPeriodGroupValue);

    String getClipsFound() {
      if (_exportPeriodGroupValue == ExportDateRange.custom) {
        return customSelectedVideos.length.toString();
      }
      return selectedVideos.length.toString();
    }

    return Scaffold(
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
                      left: MediaQuery.of(context).size.width * 0.04,
                      bottom: MediaQuery.of(context).size.height * 0.01,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Date Range',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.height * 0.025,
                          ),
                        ),
                        Text('Clips found: ${getClipsFound()}'),
                      ],
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
                              await selectVideosFromStorage();
                            }
                          },
                          items: _exportPeriods.map<DropdownMenuItem<ExportDateRange>>(
                            (ExportDateRange value) {
                              return DropdownMenuItem<ExportDateRange>(
                                value: value,
                                child: Text(value.label),
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

              // Orientation
              // Column(
              //   crossAxisAlignment: CrossAxisAlignment.start,
              //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              //   children: [
              //     Padding(
              //       padding: EdgeInsets.only(
              //         left: MediaQuery.of(context).size.width * 0.04,
              //         bottom: MediaQuery.of(context).size.height * 0.01,
              //       ),
              //       child: Text(
              //         'Orientation',
              //         style: TextStyle(
              //           fontSize: MediaQuery.of(context).size.height * 0.025,
              //         ),
              //       ),
              //     ),
              //     Padding(
              //       padding: EdgeInsets.only(
              //         left: MediaQuery.of(context).size.height * 0.025,
              //       ),
              //       child: Align(
              //         alignment: Alignment.centerLeft,
              //         child: SizedBox(
              //           width: 300,
              //           child: DropdownButtonFormField<String>(
              //             value: _orientationDefaultValue,
              //             icon: const Icon(Icons.expand_more),
              //             iconSize: 24,
              //             elevation: 16,
              //             borderRadius: BorderRadius.circular(12),
              //             isExpanded: true,
              //             dropdownColor:
              //                 ThemeService().isDarkTheme() ? AppColors.dark : AppColors.light,
              //             decoration: InputDecoration(
              //               enabledBorder: dropdownBorder,
              //               focusedBorder: dropdownBorder,
              //               border: dropdownBorder,
              //               filled: true,
              //               fillColor: ThemeService().isDarkTheme()
              //                   ? AppColors.dark
              //                   : AppColors.light,
              //             ),
              //             onChanged: (newValue) {
              //               setState(() {
              //                 _orientationDefaultValue = newValue!;
              //               });
              //             },
              //             items: _orientationValues.map<DropdownMenuItem<String>>(
              //               (String value) {
              //                 return DropdownMenuItem<String>(
              //                   value: value,
              //                   child: Text(value),
              //                 );
              //               },
              //             ).toList(),
              //           ),
              //         ),
              //       ),
              //     ),
              //   ],
              // ),

              const Spacer(),

              // Create movie button
              CreateMovieButton(
                selectedExportDateRange: _exportPeriodGroupValue,
                // selectedOrientation: _orientationDefaultValue,
                customSelectedVideos: customSelectedVideos,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
