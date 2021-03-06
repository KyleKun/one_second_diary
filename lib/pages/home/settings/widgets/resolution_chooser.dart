// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:one_second_diary/controllers/resolution_controller.dart';
// import 'package:one_second_diary/utils/custom_dialog.dart';

// class ResolutionChooser extends StatelessWidget {
//   final String title = 'videoQuality'.tr;
//   final ResolutionController _resolutionController = Get.find();

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           padding: EdgeInsets.symmetric(horizontal: 15.0),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 title,
//                 style: TextStyle(
//                   fontSize: MediaQuery.of(context).size.width * 0.045,
//                 ),
//               ),
//               Obx(
//                 () => DropdownButton<String>(
//                   iconSize: MediaQuery.of(context).size.width * 0.045,
//                   isExpanded: false,
//                   isDense: false,
//                   value: _resolutionController.resolution.value,
//                   onChanged: (mode) {
//                     if (mode == 'veryHigh') {
//                       showDialog(
//                         context: Get.context,
//                         builder: (context) => CustomDialog(
//                           isDoubleAction: false,
//                           title: 'Attention!',
//                           content:
//                               'This is an experimental feature, older devices may not support it.',
//                           actionText: 'Ok',
//                           actionColor: Colors.green,
//                           action: () => Get.back(),
//                         ),
//                       );
//                     }
//                     _resolutionController.changeResolution = mode;
//                   },
//                   items: _resolutionController.allResolutions.map(
//                     (ResolutionModel _resolution) {
//                       return DropdownMenuItem<String>(
//                         child: new Text(
//                           _resolution.mode,
//                           style: TextStyle(
//                             fontSize: MediaQuery.of(context).size.width * 0.04,
//                           ),
//                         ),
//                         value: _resolution.resolution,
//                       );
//                     },
//                   ).toList(),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Divider(),
//       ],
//     );
//   }
// }
