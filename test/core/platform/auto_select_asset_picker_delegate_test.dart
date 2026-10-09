// The picker's own paging is skipped (`DefaultAssetPickerProvider.forTest`):
// the grid's items are given, and no gallery is read.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/auto_select_asset_picker_delegate.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

void main() {
  final List<AssetEntity> gallery = <AssetEntity>[
    for (int i = 1; i <= 3; i++)
      AssetEntity(
        id: 'photo-$i',
        typeInt: AssetType.image.index,
        width: 1920,
        height: 1080,
      ),
  ];

  late DefaultAssetPickerProvider provider;

  /// The picker's page, as `AssetPicker.pickAssetsWithDelegate` pushes it,
  /// and what it completes with: what the preview's Confirm gave back.
  late BuildContext picker;
  late Future<List<AssetEntity>?> picked;
  bool pickerClosed = false;

  setUp(() {
    provider = DefaultAssetPickerProvider.forTest(maxAssets: 1)
      ..currentAssets = gallery;
    pickerClosed = false;
  });
  tearDown(() => provider.dispose());

  Future<void> openPicker(WidgetTester tester) async {
    // The gallery answers the permission check the preview repeats and says
    // each item is on the phone; the pictures themselves stay blank.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.fluttercandies/photo_manager'),
      (MethodCall call) async => switch (call.method) {
        'requestPermissionExtend' => PermissionState.authorized.index,
        'isLocallyAvailable' => true,
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.fluttercandies/photo_manager'),
        null,
      ),
    );
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox.expand()),
    );
    picked = navigator.currentState!.push(
      MaterialPageRoute<List<AssetEntity>>(
        builder: (BuildContext context) {
          picker = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    );
    picked.whenComplete(() => pickerClosed = true).ignore();
    await tester.pumpAndSettle();
  }

  /// Opens the preview on the item at [index] of the grid, as a tap on its
  /// preview corner does.
  Future<void> preview(WidgetTester tester, int index) async {
    AutoSelectAssetPickerBuilderDelegate(
      provider: provider,
      initialPermission: PermissionState.authorized,
      locale: const Locale('en'),
    ).viewAsset(picker, index, gallery[index]).ignore();
    await tester.pumpAndSettle();
  }

  /// The preview's Confirm, enabled: one of one selected.
  Finder confirm() => find.widgetWithText(MaterialButton, 'Confirm (1/1)');

  testWidgets('previewing an item selects it in place of the one selected '
      'before, a swipe selects the item it brings into view, and Confirm '
      'gives it back', (tester) async {
    await openPicker(tester);
    provider.selectAsset(gallery[2]);

    await preview(tester, 0);
    expect(provider.selectedAssets, <AssetEntity>[gallery[0]]);

    await tester.flingFrom(
      tester.getCenter(find.byType(MaterialApp)),
      const Offset(-600, 0),
      2000,
    );
    await tester.pumpAndSettle();
    expect(provider.selectedAssets, <AssetEntity>[gallery[1]]);

    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(await picked, <AssetEntity>[gallery[1]]);
  });

  testWidgets('leaving the preview without Confirm selects nothing; the '
      'picker stays', (tester) async {
    await openPicker(tester);
    await preview(tester, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(provider.selectedAssets, isEmpty);
    expect(confirm(), findsNothing);
    expect(pickerClosed, isFalse);
  });
}
