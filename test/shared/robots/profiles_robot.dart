import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/pages/profile_list_page.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/edit_profile_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/new_profile_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_photo_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/quality_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/found_profile_tile.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_name_field.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_photo_picker.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/quality_row.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/shared/widgets/controls/profile_tile.dart';

import '../harness/settle.dart';

/// Profiles, the New profile and Edit profile sheets and their photo
/// sheet, as the user drives them.
///
/// Creating, saving and deleting go through real files (the profile's
/// folder, its photo, its clips), so the actions that store wait until
/// their sheet has closed.
class ProfilesRobot {
  ProfilesRobot(this.tester);

  final WidgetTester tester;

  BuildContext get _app => tester.element(find.byType(Navigator).first);

  Finder get _page => find.byKey(const ValueKey<AppRoute>(AppRoute.profiles));

  /// The active profile is called [name] (Default's name is translated).
  void expectActiveName(String name) =>
      expect(_app.read<ProfilesCubit>().state.active.displayName, name);

  void expectShown() => expect(_page, findsOneWidget);

  /// The profile tiles' names, top to bottom.
  List<String> get names => <String>[
    for (final ProfileTile tile in tester.widgetList<ProfileTile>(
      find.descendant(of: _page, matching: find.byType(ProfileTile)),
    ))
      tile.name,
  ];

  /// The name on the tile marked "Active".
  String get activeTile => tester
      .widgetList<ProfileTile>(
        find.descendant(of: _page, matching: find.byType(ProfileTile)),
      )
      .singleWhere((ProfileTile tile) => tile.active)
      .name;

  /// The row under [profile]'s name ("Landscape · 3 videos").
  String subtitleOf(ProfileKey profile) =>
      tester.widget<ProfileTile>(_tile(profile)).subtitle;

  Finder _tile(ProfileKey profile) =>
      find.byKey(ProfileListPage.tileKey(profile));

  /// Taps [profile]'s tile (activates it).
  Future<void> tapTile(ProfileKey profile) async {
    await _reveal(find.byKey(ProfileListPage.tileKey(profile)));
    await tester.tap(find.byKey(ProfileListPage.tileKey(profile)));
    await settle(tester);
  }

  /// Long-presses [profile]'s tile, which opens its Edit profile sheet.
  Future<void> openEdit(ProfileKey profile) async {
    await _reveal(find.byKey(ProfileListPage.tileKey(profile)));
    await tester.longPress(find.byKey(ProfileListPage.tileKey(profile)));
    await settle(tester);
    expect(find.byType(EditProfileSheet), findsOneWidget);
  }

  /// Taps "Create new profile", which opens the New profile sheet.
  Future<void> openNew() async {
    await tester.tap(find.byKey(ProfileListPage.createKey));
    await settle(tester);
    expect(find.byType(NewProfileSheet), findsOneWidget);
  }

  /// The folders offered back, top to bottom.
  List<String> get found => <String>[
    for (final FoundProfileTile tile in tester.widgetList<FoundProfileTile>(
      find.descendant(of: _page, matching: find.byType(FoundProfileTile)),
    ))
      tile.name,
  ];

  /// Waits until the page offers [folders] back (they are read from the disk).
  Future<void> expectFound(List<String> folders) => _settleUntil(
    () => _listEquals(found, folders),
    reason: 'S4 offers $folders back (shows $found)',
  );

  /// Taps "Add back" on [folder] and waits until it is a profile.
  Future<void> addBack(ProfileKey folder) async {
    final Finder button = find.byKey(ProfileListPage.addBackKey(folder));
    await _reveal(button);
    await tester.tap(button);
    await _settleUntil(
      () =>
          find.byKey(ProfileListPage.tileKey(folder)).evaluate().isNotEmpty &&
          find.byKey(ProfileListPage.foundKey(folder)).evaluate().isEmpty,
      reason: '${folder.value} is a profile again',
    );
  }

  /// Whether a profile sheet (New or Edit) shows.
  bool get sheetOpen =>
      find.byType(NewProfileSheet).evaluate().isNotEmpty ||
      find.byType(EditProfileSheet).evaluate().isNotEmpty;

  /// Types [name] in the name field.
  Future<void> enterName(String name) async {
    await tester.enterText(find.byKey(ProfileNameField.fieldKey), name);
    await settle(tester);
  }

  String get nameText => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(ProfileNameField.fieldKey),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  /// The error under the name field, or null.
  String? get nameError => tester
      .widget<OsdTextField>(find.byKey(ProfileNameField.fieldKey))
      .errorText;

  /// Picks [orientation] for a new profile.
  Future<void> pickOrientation(VideoOrientation orientation) async {
    await _reveal(find.byKey(NewProfileSheet.orientationKey(orientation)));
    await tester.tap(find.byKey(NewProfileSheet.orientationKey(orientation)));
    await settle(tester);
  }

  /// Opens the quality sheet from the Quality row (once the canvas is
  /// chosen and the phone check's advice is in), picks [preset] and taps
  /// "Use this quality".
  Future<void> pickQuality(ClipFormatPreset preset) async {
    await _settleUntil(
      () =>
          find.byType(QualityRow).evaluate().isNotEmpty &&
          tester.widget<QualityRow>(find.byType(QualityRow)).enabled,
      reason: 'the Quality row is ready',
    );
    await _reveal(find.byKey(QualityRow.rowKey));
    await tester.tap(find.byKey(QualityRow.rowKey));
    await settle(tester);
    expect(find.byType(QualitySheet), findsOneWidget);
    await _reveal(find.byKey(QualitySheet.presetKey(preset)));
    await tester.tap(find.byKey(QualitySheet.presetKey(preset)));
    await settle(tester);
    await _reveal(find.byKey(QualitySheet.useKey));
    await tester.tap(find.byKey(QualitySheet.useKey));
    await settle(tester);
    expect(find.byType(QualitySheet), findsNothing);
  }

  /// Taps the photo, then [choice] in the photo sheet.
  Future<void> choosePhoto(ProfilePhotoChoice choice) async {
    await openPhotoSheet();
    await tester.tap(find.byKey(ProfilePhotoSheet.rowKey(choice)));
    await settle(tester);
  }

  /// Taps the photo (or its caption), which opens the photo sheet.
  Future<void> openPhotoSheet() async {
    await _reveal(find.byKey(ProfilePhotoPicker.pickerKey));
    await tester.tap(find.byKey(ProfilePhotoPicker.pickerKey));
    await settle(tester);
    expect(find.byType(ProfilePhotoSheet), findsOneWidget);
  }

  /// The choices the photo sheet offers, top to bottom.
  List<ProfilePhotoChoice> get photoChoices => <ProfilePhotoChoice>[
    for (final ProfilePhotoChoice choice in ProfilePhotoChoice.values)
      if (find.byKey(ProfilePhotoSheet.rowKey(choice)).evaluate().isNotEmpty)
        choice,
  ];

  Finder get _submit => find.byWidgetPredicate(
    (Widget widget) =>
        widget is PrimaryButton &&
        (widget.key == NewProfileSheet.createKey ||
            widget.key == EditProfileSheet.saveKey),
  );

  /// Whether Create (New profile) or Save (Edit profile) can be tapped.
  bool get submitEnabled =>
      tester.widget<PrimaryButton>(_submit).onPressed != null;

  /// Taps Create or Save and waits until the sheet has closed.
  Future<void> submit() async {
    await _reveal(_submit);
    await tester.tap(_submit);
    await _settleUntil(
      () => !sheetOpen,
      reason: 'the profile is stored and its sheet closed',
    );
  }

  /// Whether Edit profile offers "Delete profile".
  bool get canDelete =>
      find.byKey(EditProfileSheet.deleteKey).evaluate().isNotEmpty;

  /// Taps "Delete profile" and opens its confirmation.
  Future<void> tapDelete() async {
    await _reveal(find.byKey(EditProfileSheet.deleteKey));
    await tester.tap(find.byKey(EditProfileSheet.deleteKey));
    await settle(tester);
    expect(find.byType(OsdConfirmDialog), findsOneWidget);
  }

  /// Deletes the profile being edited: "Delete profile", then "Delete" in
  /// the confirmation; waits until the sheet has closed.
  Future<void> delete() async {
    await tapDelete();
    await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
    await _settleUntil(
      () => !sheetOpen,
      reason: 'the profile is deleted and its sheet closed',
    );
  }

  /// Closes the sheet on top with the system back.
  Future<void> pressBack() async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  Future<void> _reveal(Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
  }

  /// Pumps until [condition] holds, letting real file work finish between
  /// frames (the harness's shared `settleUntil`).
  Future<void> _settleUntil(
    bool Function() condition, {
    required String reason,
  }) => settleUntil(tester, condition, reason: reason);

  static bool _listEquals(List<String> a, List<String> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((int i) => a[i] == b[i]);
}
