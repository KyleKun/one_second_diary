import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';

/// What the in-app gallery picker was opened with.
typedef GalleryPickRequest = ({
  PickerMedia media,
  DateTime? from,
  String firstCellLabel,
});

/// Scriptable pickers. Each list of answers is used in order; when it runs
/// out the user cancels. The requests say what each picker was opened
/// with.
class FakePickerGateway implements PickerGateway {
  final List<PickerOutcome> galleryAnswers = <PickerOutcome>[];

  final List<PickerOutcome> systemAnswers = <PickerOutcome>[];

  final List<PickerOutcome> cameraAnswers = <PickerOutcome>[];

  final List<PickerOutcome> photoAnswers = <PickerOutcome>[];

  /// What Android kept while the app was away (`retrieveLostPick`), handed
  /// out once.
  LostPick? lost;

  final List<GalleryPickRequest> galleryRequests = <GalleryPickRequest>[];
  final List<PickerMedia> systemRequests = <PickerMedia>[];
  final List<PhotoOrigin> photoRequests = <PhotoOrigin>[];

  bool cameraOpened = false;

  /// Whether anything asked for a lost pick.
  bool lostPickAsked = false;

  /// Whether no picker was opened.
  bool get untouched =>
      galleryRequests.isEmpty &&
      systemRequests.isEmpty &&
      photoRequests.isEmpty &&
      !cameraOpened &&
      !lostPickAsked;

  static PickerOutcome _next(List<PickerOutcome> answers) =>
      answers.isEmpty ? const PickCancelled() : answers.removeAt(0);

  @override
  Future<PickerOutcome> pickFromGallery(
    BuildContext context, {
    required PickerMedia media,
    required DateTime? from,
    required String firstCellLabel,
  }) async {
    galleryRequests.add((
      media: media,
      from: from,
      firstCellLabel: firstCellLabel,
    ));
    return _next(galleryAnswers);
  }

  @override
  Future<PickerOutcome> pickWithSystemPicker({
    required PickerMedia media,
  }) async {
    systemRequests.add(media);
    return _next(systemAnswers);
  }

  @override
  Future<PickerOutcome> recordWithSystemCamera() async {
    cameraOpened = true;
    return _next(cameraAnswers);
  }

  @override
  Future<PickerOutcome> pickProfilePhoto({required PhotoOrigin origin}) async {
    photoRequests.add(origin);
    return _next(photoAnswers);
  }

  @override
  Future<LostPick?> retrieveLostPick() async {
    lostPickAsked = true;
    final LostPick? pick = lost;
    lost = null;
    return pick;
  }
}
