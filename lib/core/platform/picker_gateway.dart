import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// What a picker picks.
enum PickerMedia { video, photo }

/// Where a profile photo comes from.
enum PhotoOrigin { camera, gallery }

/// How a pick ended.
sealed class PickerOutcome extends Equatable {
  const PickerOutcome();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The user picked (or recorded) the file at [path].
final class Picked extends PickerOutcome {
  const Picked(this.path);

  final String path;

  @override
  List<Object?> get props => <Object?>[path];
}

/// The user left the picker without picking.
final class PickCancelled extends PickerOutcome {
  const PickCancelled();
}

/// The phone refused the gallery or camera permission the picker needs.
final class PickDenied extends PickerOutcome {
  const PickDenied();
}

/// The user picked something the platform could not hand over: an iCloud
/// item that did not download, limited photo access. The caller says so.
final class PickUnavailable extends PickerOutcome {
  const PickUnavailable();
}

/// A pick Android delivered after it destroyed the app while the system
/// picker or camera was open (image_picker's `retrieveLostData`).
final class LostPick extends Equatable {
  const LostPick({required this.path, required this.media});

  final String path;
  final PickerMedia media;

  @override
  List<Object?> get props => <Object?>[path, media];
}

/// The pickers: the in-app gallery picker (the `wechat_assets_picker` fork),
/// the system picker and camera (`image_picker`), and profile photos.
///
/// Who owns a picked file (never delete an Android original; an iOS export
/// is a temp copy), the picker preferences, the day filter and the
/// self-import guard live above this boundary (`ImportFlow`).
abstract interface class PickerGateway {
  /// The in-app gallery picker ("Use experimental file picker", on by
  /// default), which opens its own page from [context]: one [media] item;
  /// previewing an item selects it, so Confirm works from the preview. With
  /// [from], only items created from then until now, oldest first ("Use
  /// date filter"). [firstCellLabel] is the text of the grid's first cell
  /// ("Latest videos", or "From … onwards").
  ///
  /// On Android the file is the user's own gallery file; on iOS a copy the
  /// platform exported into the app's temp folder.
  Future<PickerOutcome> pickFromGallery(
    BuildContext context, {
    required PickerMedia media,
    required DateTime? from,
    required String firstCellLabel,
  });

  /// The system picker ("Use experimental file picker" off). The file is a
  /// copy in the app's cache.
  Future<PickerOutcome> pickWithSystemPicker({required PickerMedia media});

  /// The system camera app, recording a video: on Android below API 29,
  /// and with "Force native camera". No length limit and no preferred lens;
  /// the clip editor trims it.
  Future<PickerOutcome> recordWithSystemCamera();

  /// A profile photo from [origin], at most 512 px on its longer side.
  Future<PickerOutcome> pickProfilePhoto({required PhotoOrigin origin});

  /// A pick Android delivered after it destroyed the app while the system
  /// picker or camera was open, or null (always on iOS). Ask once, at
  /// launch.
  Future<LostPick?> retrieveLostPick();
}
