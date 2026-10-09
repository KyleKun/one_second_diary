import 'package:flutter/widgets.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// The in-app gallery picker's builder with one change: previewing an item
/// selects it, and swiping in the preview selects the item shown, so
/// Confirm works right from the preview.
class AutoSelectAssetPickerBuilderDelegate
    extends DefaultAssetPickerBuilderDelegate<DefaultAssetPickerProvider> {
  AutoSelectAssetPickerBuilderDelegate({
    required super.provider,
    required super.initialPermission,
    super.pickerTheme,
    super.specialItems,
    super.locale,
  });

  @override
  Future<void> viewAsset(
    BuildContext context,
    int? index,
    AssetEntity currentAsset,
  ) async {
    final List<AssetEntity> current;
    final int effectiveIndex;

    if (index == null) {
      current = provider.selectedAssets;
      effectiveIndex = current.indexOf(currentAsset);
    } else {
      current = provider.currentAssets;
      effectiveIndex = index;
    }

    if (current.isEmpty) {
      return;
    }

    // Perform the initial auto-selection BEFORE creating the viewer
    // delegate, so that its internal `selectedAssets` list captures the
    // selected state, which enables the Confirm button.
    if (!provider.selectedAssets.contains(currentAsset)) {
      final List<AssetEntity> selected = List<AssetEntity>.of(
        provider.selectedAssets,
      );
      selected.forEach(provider.unSelectAsset);
      provider.selectAsset(currentAsset);
    }

    final DefaultAssetPickerViewerBuilderDelegate<
      AssetPickerViewerProvider<AssetEntity>,
      DefaultAssetPickerProvider
    >
    viewerDelegate =
        DefaultAssetPickerViewerBuilderDelegate<
          AssetPickerViewerProvider<AssetEntity>,
          DefaultAssetPickerProvider
        >(
          currentIndex: effectiveIndex,
          previewAssets: current,
          provider: AssetPickerViewerProvider<AssetEntity>(
            provider.selectedAssets,
            maxAssets: provider.maxAssets,
          ),
          themeData: theme,
          selectedAssets: provider.selectedAssets,
          selectorProvider: provider,
          maxAssets: provider.maxAssets,
        );

    // Swipe auto-selection.
    viewerDelegate.pageStreamController.stream.listen((int pageIndex) {
      final AssetEntity asset = current[pageIndex];
      if (!provider.selectedAssets.contains(asset)) {
        final List<AssetEntity> selected = List<AssetEntity>.of(
          provider.selectedAssets,
        );
        selected.forEach(viewerDelegate.unSelectAsset);
        viewerDelegate.selectAsset(asset);
      }
    });

    final List<AssetEntity>? result =
        await AssetPickerViewer.pushToViewerWithDelegate<
          AssetEntity,
          AssetPathEntity,
          AssetPickerViewerProvider<AssetEntity>,
          DefaultAssetPickerViewerBuilderDelegate<
            AssetPickerViewerProvider<AssetEntity>,
            DefaultAssetPickerProvider
          >
        >(context, delegate: viewerDelegate);

    if (!context.mounted) return;
    if (result != null) {
      await Navigator.maybeOf(context)?.maybePop(result);
    } else {
      final List<AssetEntity> selected = List<AssetEntity>.of(
        provider.selectedAssets,
      );
      selected.forEach(provider.unSelectAsset);
    }
  }
}
