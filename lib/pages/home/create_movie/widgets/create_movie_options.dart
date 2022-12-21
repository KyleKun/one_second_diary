import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:group_radio_button/group_radio_button.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/utils/utils.dart';

import '../../../../enums/export_date_range.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/date_format_utils.dart';
import '../../../../utils/theme.dart';
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

  final dropdownBorder = OutlineInputBorder(
    borderSide: BorderSide(
      color: ThemeService().isDarkTheme() ? Colors.black : Colors.white,
      width: 2,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final selectedVideos = Utils.getSelectedVideosFromStorage(_exportPeriodGroupValue);

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
                        Text('Clips found: ${selectedVideos.length}'),
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
                          onChanged: (newValue) {
                            setState(() {
                              _exportPeriodGroupValue = newValue!;
                            });
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

              SizedBox(height: MediaQuery.of(context).size.height * 0.045),

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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
