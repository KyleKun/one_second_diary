import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/auto_select_asset_picker_delegate.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_fonts.dart';
import 'package:one_second_diary/theme/osd_typography.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// [PickerGateway] over the `wechat_assets_picker` fork (the in-app gallery
/// picker) and `image_picker` (the system picker and camera, profile
/// photos, lost picks).
final class PluginPickerGateway implements PickerGateway {
  PluginPickerGateway({
    required this._imagePicker,
    required this._clock,
    required this._isAndroid,
    required this._logger,
  });

  final ImagePicker _imagePicker;
  final Clock _clock;
  final bool _isAndroid;
  final AppLogger _logger;

  static const String _tag = 'PICKER';

  /// The longer side of a profile photo.
  static const double profilePhotoSize = 512;

  @override
  Future<PickerOutcome> pickFromGallery(
    BuildContext context, {
    required PickerMedia media,
    required DateTime? from,
    required String firstCellLabel,
  }) async {
    final RequestType type = switch (media) {
      PickerMedia.video => RequestType.video,
      PickerMedia.photo => RequestType.image,
    };
    final PermissionState permission;
    try {
      permission = await AssetPicker.permissionCheck(
        requestOption: PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: type,
            mediaLocation: false,
          ),
        ),
      );
    } on StateError catch (error) {
      _logger.warning(_tag, 'Gallery permission refused', error: error);
      return const PickDenied();
    }
    if (!context.mounted) return const PickCancelled();
    final AutoSelectAssetPickerBuilderDelegate delegate =
        AutoSelectAssetPickerBuilderDelegate(
          provider: DefaultAssetPickerProvider(
            maxAssets: 1,
            requestType: type,
            filterOptions: from == null
                ? null
                : FilterOptionGroup(
                    containsPathModified: true,
                    createTimeCond: DateTimeCond(min: from, max: _clock.now()),
                    orders: const <OrderOption>[
                      OrderOption(type: OrderOptionType.createDate, asc: true),
                    ],
                  ),
            sortPathsByModifiedDate: true,
          ),
          initialPermission: permission,
          pickerTheme: pickerThemeOf(context),
          locale: Localizations.maybeLocaleOf(context),
          specialItems: <SpecialItem<AssetPathEntity>>[
            SpecialItem<AssetPathEntity>(
              position: SpecialItemPosition.prepend,
              builder:
                  (
                    BuildContext context,
                    AssetPathEntity? path,
                    PermissionState permission,
                  ) => _FirstCell(label: firstCellLabel),
            ),
          ],
        );
    try {
      final List<AssetEntity>? picked =
          await AssetPicker.pickAssetsWithDelegate<
            AssetEntity,
            AssetPathEntity,
            DefaultAssetPickerProvider,
            AutoSelectAssetPickerBuilderDelegate
          >(context, delegate: delegate);
      if (picked == null || picked.isEmpty) return const PickCancelled();
      // A video as it is stored; a photo as a JPEG, which iOS makes of a
      // HEIC (ffmpeg cannot hold a HEIC still: "Option loop not found").
      // Android hands over the stored file either way: the import flow
      // rewrites a HEIC that still comes through.
      final File? file = await picked.first.loadFile(
        isOrigin: media != PickerMedia.photo,
      );
      if (file == null) {
        _logger.warning(_tag, 'The picked item could not be loaded');
        return const PickUnavailable();
      }
      return Picked(file.path);
    } on StateError catch (error) {
      _logger.warning(_tag, 'Gallery permission refused', error: error);
      return const PickDenied();
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'The gallery picker failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const PickUnavailable();
    }
  }

  /// The in-app picker in the app's theme: coral accents (the picker's own
  /// default is WeChat's green), light or dark with the app, the app's
  /// surfaces and font. The app's theme extensions come along, so the
  /// picker's first cell reads the app's colours and type.
  @visibleForTesting
  static ThemeData pickerThemeOf(BuildContext context) {
    final ThemeData app = Theme.of(context);
    final OsdColors colors = context.colors;
    final ThemeData base = AssetPicker.themeData(
      colors.co,
      light: app.brightness == Brightness.light,
    );
    return base.copyWith(
      primaryColor: colors.bg,
      scaffoldBackgroundColor: colors.bg,
      cardColor: colors.bg,
      canvasColor: colors.card,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: colors.card,
        foregroundColor: colors.tx,
        iconTheme: IconThemeData(color: colors.tx),
      ),
      bottomAppBarTheme: base.bottomAppBarTheme.copyWith(color: colors.card),
      iconTheme: base.iconTheme.copyWith(color: colors.tx),
      colorScheme: base.colorScheme.copyWith(
        primary: colors.bg,
        surface: colors.bg,
        onSurface: colors.tx,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: OsdFonts.rubik,
        bodyColor: colors.tx,
        displayColor: colors.tx,
      ),
      extensions: app.extensions.values,
    );
  }

  @override
  Future<PickerOutcome> pickWithSystemPicker({
    required PickerMedia media,
  }) => _pick(
    () => switch (media) {
      PickerMedia.video => _imagePicker.pickVideo(source: ImageSource.gallery),
      PickerMedia.photo => _imagePicker.pickImage(source: ImageSource.gallery),
    },
  );

  @override
  Future<PickerOutcome> recordWithSystemCamera() =>
      _pick(() => _imagePicker.pickVideo(source: ImageSource.camera));

  @override
  Future<PickerOutcome> pickProfilePhoto({required PhotoOrigin origin}) =>
      _pick(
        () => _imagePicker.pickImage(
          source: switch (origin) {
            PhotoOrigin.camera => ImageSource.camera,
            PhotoOrigin.gallery => ImageSource.gallery,
          },
          maxWidth: profilePhotoSize,
          maxHeight: profilePhotoSize,
          imageQuality: 90,
          preferredCameraDevice: CameraDevice.front,
        ),
      );

  @override
  Future<LostPick?> retrieveLostPick() async {
    if (!_isAndroid) return null;
    try {
      final LostDataResponse lost = await _imagePicker.retrieveLostData();
      final XFile? file = lost.file;
      if (lost.isEmpty || file == null) {
        if (lost.exception != null) {
          _logger.warning(
            _tag,
            'A pick lost while the app was away failed',
            error: lost.exception,
          );
        }
        return null;
      }
      _logger.info(_tag, 'Recovered a pick lost while the app was away');
      return LostPick(
        path: file.path,
        media: lost.type == RetrieveType.video
            ? PickerMedia.video
            : PickerMedia.photo,
      );
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not read a lost pick',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<PickerOutcome> _pick(Future<XFile?> Function() pick) async {
    try {
      final XFile? file = await pick();
      return file == null ? const PickCancelled() : Picked(file.path);
    } on PlatformException catch (error) {
      if (error.code.endsWith('access_denied')) {
        _logger.warning(_tag, 'Permission refused', error: error);
        return const PickDenied();
      }
      _logger.error(_tag, 'The system picker failed', error: error);
      return const PickUnavailable();
    }
  }
}

/// The grid's first cell (a special item): "Latest videos", or the day the
/// filter starts from.
class _FirstCell extends StatelessWidget {
  const _FirstCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: context.typography.label14Strong.copyWith(
          color: context.colors.tx,
        ),
      ),
    );
  }
}
