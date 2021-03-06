// import 'package:camera/camera.dart';
// import 'package:get/get.dart';
// import 'package:one_second_diary/utils/shared_preferences_util.dart';
// import 'package:one_second_diary/utils/utils.dart';

// class ResolutionModel {
//   ResolutionModel(
//     this.mode,
//     this.resolution,
//   );

//   String mode;
//   String resolution;
// }

// class ResolutionController extends GetxController {
//   @override
//   void onInit() {
//     resolution = _getResolution();
//     super.onInit();
//   }

//   final List<ResolutionModel> allResolutions = [
//     ResolutionModel('Medium', 'medium'),
//     ResolutionModel('High', 'high'),
//     ResolutionModel('Very High', 'veryHigh'),
//   ];

//   var resolution = StorageUtil.getString('resolution').obs;

//   // Position X used to place date on video
//   var editX = 1120.obs;
//   var dateSize = 25.obs;

//   ResolutionPreset selectResolution() {
//     switch (resolution.value) {
//       case 'medium':
//         editX.value = 630;
//         dateSize.value = 15;
//         editX.refresh();
//         dateSize.refresh();
//         return ResolutionPreset.medium;
//       case 'high':
//         editX.value = 1120;
//         dateSize.value = 25;
//         editX.refresh();
//         dateSize.refresh();
//         return ResolutionPreset.high;
//       case 'veryHigh':
//         editX.value = 1690;
//         dateSize.value = 35;
//         editX.refresh();
//         dateSize.refresh();
//         return ResolutionPreset.veryHigh;
//       default:
//         editX.value = 1120;
//         dateSize.value = 25;
//         editX.refresh();
//         dateSize.refresh();
//         return ResolutionPreset.high;
//     }
//   }

//   set changeResolution(String mode) {
//     StorageUtil.putString('resolution', mode);
//     resolution.value = mode;
//     resolution.refresh();
//     // Utils().logInfo('Resolution: ${resolution.value}');
//   }

//   RxString _getResolution() {
//     if (StorageUtil.getString('resolution').length < 4) {
//       // Utils().logInfo('No resolution configured!');
//       StorageUtil.putString('resolution', 'high');
//     }
//     // Utils().logInfo('Resolution: ${StorageUtil.getString('resolution')}');
//     return StorageUtil.getString('resolution').obs;
//   }

//   // void _checkCodec() async {
//   //   isHighRes.value = false;
//   //   bool shouldUseHigherCodec = await Utils.shouldUseHigherCodec();

//   //   if (shouldUseHigherCodec && !isHighRes.value) {
//   //     StorageUtil.putBool('isHighRes', true);
//   //     isHighRes.value = StorageUtil.getBool('isHighRes');
//   //   }

//   //   isHighRes.refresh();

//   //   Utils().logInfo('Is High Res?: ${isHighRes.value}');
//   // }
// }
