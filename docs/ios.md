# Running One Second Diary on iOS

This document covers what is different on iOS, the one licensing decision that
has to be made before shipping to the App Store, and how to build.

## Where the files live

Android keeps the diary in `DCIM/OneSecondDiary/`, a folder the system gallery
indexes and the user can browse. iOS has no equivalent: an app either owns a
private container or writes into the photo library through `PHPhotoLibrary`.

The app takes the first option and stores the diary in its own `Documents`
folder. With `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`
set in `Info.plist`, that folder shows up as **One Second Diary** in the Files
app, which is the closest thing to the visible Android folder: the user can
browse, copy and back up their videos without the app doing anything.

| | Android | iOS |
|---|---|---|
| videos | `<storage root>/DCIM/OneSecondDiary/` | `<Documents>/OneSecondDiary/` |
| movies | `.../OneSecondDiary/Movies/` | `<Documents>/OneSecondDiary/Movies/` |
| logs, scratch files | `<Documents>` | `<Application Support>` |

Scratch files stay out of `Documents` on iOS so the folder the user sees only
ever contains videos.

### Absolute paths are never persisted

The iOS application container is rooted at a UUID that is regenerated on every
reinstall, OS migration and backup restore. An absolute path stored in
`SharedPreferences` by one launch does not resolve on the next one, and the app
would look like it had lost every video.

`AppPaths` therefore resolves the folders once per launch, from
`path_provider`, and keeps them in memory. The `appPath` / `moviesPath` /
`internalDirectoryPath` preference keys are still written, because the Android
folder migration reads them, but nothing reads them back as a source of truth.

## The encoder, and why it is not libx264

`libx264` is GPL. ffmpeg-kit ships it only in its `*_gpl` flavours, and linking
a GPL library into an App Store binary is not possible: the GPL forbids the
additional restrictions Apple's distribution terms impose. This is the same
wall VLC ran into.

So on iOS the app encodes with **VideoToolbox**, Apple's hardware H.264
encoder. It is available in every ffmpeg-kit flavour, it is several times
faster than x264, and it has no licensing problem. It also has no CRF mode, so
the quality target that used to be `-crf 20 -preset slow` is expressed as a
bitrate (12 Mbps at 1080p30, see `EncoderSelector.targetBitrateKbps`).

`EncoderSelector` (`lib/core/media/policy/encoder_selector.dart`) reads
`ffmpeg -hide_banner -encoders` once, before the first media job, and picks:

| | first choice | fallback |
|---|---|---|
| iOS | `h264_videotoolbox` | `libx264` |
| Android | `libx264` | `h264_mediacodec` |

Because the choice is made at runtime, the app works with either flavour of
ffmpeg-kit without a code change. Only
`lib/core/platform/ffmpeg_kit_gateway.dart` imports the package.

- **`full-gpl`, the current default** (`ffmpeg_kit_flutter_new` from pub.dev).
  Android uses libx264 and renders exactly what earlier releases rendered. iOS
  uses VideoToolbox. Fine for Google Play and for sideloading, but **not**
  distributable on the App Store.
- **`full` (LGPL 3.0).** No x264, x265, xvidcore or vid.stab. Android would
  fall back to MediaCodec; iOS keeps VideoToolbox. This is the flavour an App
  Store build has to use.

### Switching iOS to LGPL without touching Android

The plugin cannot pick a flavour per platform from `pubspec.yaml`: one
`ffmpeg_kit_flutter_new` (4.6.2) serves both platforms, and each platform
hard-codes its binaries:

| | where the flavour is fixed | GPL | LGPL |
|---|---|---|---|
| Android | `android/build.gradle` | `com.antonkarpenko:ffmpeg-kit-full-gpl:2.2.1` | left alone |
| iOS, Swift Package Manager | `ios/ffmpeg_kit_flutter_new/Package.swift` | `ffmpegTag = "8.1.2-full-gpl"` | `8.1.2-full` |
| iOS, CocoaPods | `scripts/setup_ios.sh` | `VARIANT="full-gpl"` | `full` |

The pub.dev flavour packages (`ffmpeg_kit_flutter_new_full` and the others)
are not an option: switching to one changes Android too, which would silently
move every Android render from libx264 to MediaCodec.

So the switch is a fork of the plugin with only its iOS side changed, pinned
in **one file of this repo**, the way `video_player` and `video_trimmer` are
already pinned:

1. Fork `https://github.com/sk3llo/ffmpeg_kit_flutter` at the commit whose
   `pubspec.yaml` has the version in this repo's `pubspec.lock` (4.6.2 today;
   the package lives at the repository root).
2. In the fork, change the two iOS files and nothing else:
   - `ios/ffmpeg_kit_flutter_new/Package.swift`: set
     `let ffmpegTag = "8.1.2-full"`, and replace the eight checksums with the
     ones published in
     `https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/8.1.2-full/checksums.json`:

     ```swift
     ("ffmpegkit", "a565f36d1d6769523fe78aee3c015212ea7f9b1fc1007bea21e46c1d6df06bde"),
     ("libavcodec", "eb56ac124c03ebd4c91584b86fe3c6d758ed1cff1cf475cc6bca319f0f7c8106"),
     ("libavdevice", "0f1f06f636beb75936e5f840f81ec15966fb1dfaff14f78cb83bdbcc3422bb89"),
     ("libavfilter", "50eb73ebe41724444b8256c2c61541ced3fda7b2e1b20aac2f928fb2bf2d0ac6"),
     ("libavformat", "e9f08440c7e0aa3fba67e1f9f1f4c06a6fb2b9da557953fd086b2343dda6b31a"),
     ("libavutil", "70d35584a0ee9282bdbb6b02f3ce806f6ceb27b81cf148905642b468a40bfec6"),
     ("libswresample", "df15ca091b005cc984f644c68d6617ac6b9588992fa8387bb068c4f1c8a6d0be"),
     ("libswscale", "2570aab53ad07282e3539dff906d73a9c801589b1d3b33870df0ccbe892c4b07"),
     ```

   - `scripts/setup_ios.sh`: set `VARIANT="full"`. This is the CocoaPods
     path, the one the project builds with (see "CocoaPods only" below).
     `Package.swift` is changed too so that the fork stays consistent.
   - Leave `android/` as it is: Android keeps `ffmpeg-kit-full-gpl` and
     libx264.
3. In this repo's `pubspec.yaml`, replace `ffmpeg_kit_flutter_new: ^4.6.2`
   with the fork pinned to a commit, then run `flutter pub get`:

   ```yaml
   ffmpeg_kit_flutter_new:
     git:
       url: https://github.com/KyleKun/ffmpeg_kit_flutter
       ref: <commit of the iOS-LGPL change>
   ```

   The package name is unchanged, so no Dart import changes.
4. Clean before the first LGPL build, because both paths cache binaries:
   `flutter clean`, and for CocoaPods `cd ios && pod deintegrate && pod install`.
   Check what went in: `strings` on
   `Runner.app/Frameworks/libavcodec.framework/libavcodec` in the built app
   must not find `libx264`, and after the first save the app's log (the one
   Report error attaches) says `Encoding with h264_videotoolbox` under the
   `ffmpeg` tag.

To go back, point `pubspec.yaml` at pub.dev again. When the plugin is bumped,
redo step 2 on the new version: the tag and checksums change with every
native release.

### What changes on iOS with the LGPL build

Nothing the user can see:

- **Encoding.** iOS already picks `h264_videotoolbox` first, with
  `-b:v 12000k`, and never reached libx264 on a real phone. The one thing
  that goes is the libx264 fallback, used only when a build lists no
  VideoToolbox. `EncoderSelector.defaultFor(isIOS: true)` is VideoToolbox, so
  even an empty probe does not reach for x264.
- **Filters and codecs.** Everything the app runs is in the LGPL build:
  `drawtext` (freetype, fontconfig, fribidi), `subtitles` (libass), `scale`,
  `pad`, `crop`, `fps`, `format`, `trim`, `concat`, `anullsrc`, `volume`, the
  native `aac` encoder and `mov_text`. None of them is GPL-only.
- **Android** is unchanged: GPL, libx264, the same output as 1.7.1.

**LGPL obligations.** ffmpeg-kit's iOS frameworks are dynamic libraries
(`Mach-O 64-bit dynamically linked shared library`), so a user can swap
them, which is what the LGPL asks of an App Store binary. Each framework
carries its `LICENSE`, and its `SOURCE` file points to the source code. The
app's Licenses page (Settings, About) lists the plugin's licence.

**The GPL build, today and on Android.** Until the switch above, both
platforms ship `full-gpl`, and Android keeps it after the switch: x264,
x265, xvidcore and vid.stab are GPL, so the whole ffmpeg-kit build is under
the GPL 3.0. Flutter's licence collection only picks up the plugin's
`LICENSE` (LGPL 3.0), so the app bundles the GPL text itself
(`assets/licenses/ffmpeg-kit-GPLv3.txt`, copied from the plugin's
`LICENSE.GPLv3`) and lists it on the Licenses page as "ffmpeg-kit
(full-gpl)" (`lib/app/bundled_licenses.dart`). When iOS switches to LGPL,
limit that entry to Android.

## What Android has and iOS does not

- **Start recording with the volume buttons.** iOS gives no supported way to
  intercept the volume buttons, so the shortcut is guarded behind
  `LaunchCore.isAndroid` (`VolumeKeyGateway` has an Android implementation
  only).
- **MediaStore.** There is no media index to publish to.
  `SandboxMediaStoreGateway` is the sandbox implementation, where publishing
  is a move inside `Documents` and deleting is a plain unlink.
- **The pre v1.4 folder migration.** No iOS build ever wrote the old layout, so
  the migration only runs on Android.

## Building

Requires a Mac with Xcode 26.2 or later, and CocoaPods.

```bash
flutter pub get
cd ios && pod install && cd ..

# Connected device
flutter run

# Unsigned release build, which is what CI does
flutter build ios --release --no-codesign
```

The unsigned release build runs on every push to `main` and every pull
request into it, through `.github/workflows/ios-compile.yml`.

### CocoaPods only, pinned in `pubspec.yaml`

Every plugin builds through CocoaPods. `pubspec.yaml` turns Swift Package
Manager off for this project:

```yaml
flutter:
  config:
    enable-swift-package-manager: false
```

Flutter 3.47 turns SwiftPM on by default, and the project setting wins over
the machine's `flutter config`, so CI (`ios-compile.yml`), every contributor
and the App Store archive build the same configuration. The Xcode project
keeps its `FlutterGeneratedPluginSwiftPackage` reference; with SwiftPM off,
Flutter generates that package empty.

The reason is **permission_handler**. It compiles an iOS permission in only
when its `PERMISSION_*` macro is on, and otherwise answers "permanently
denied" without a prompt. Under CocoaPods the macros come from the
`post_install` block of `ios/Podfile`, which must name every permission the
app asks for on iOS (camera, microphone, photos, location while in use,
notifications); `test/app/native/ios_permissions_test.dart` checks it
against `PermissionPolicy` and `Info.plist`. Under SwiftPM the Podfile is
not read at all, and `permission_handler_apple` 9.4.9 (the version in
`pubspec.lock`) fails to find `Runner/Info.plist` from its `Package.swift`,
so it compiles every permission out: camera, microphone, photos and
location would be "permanently denied" with no prompt. Later releases fix
the lookup for `flutter build`, but still cannot find `Info.plist` from an
Xcode.app archive without `PERMISSION_HANDLER_INFO_PLIST`. Turning SwiftPM
back on needs both, and an archive-build check of every prompt.

After changing the Podfile or the plugins, run `cd ios && pod install` and
commit `ios/Podfile.lock`: CI runs `pod install` against it.

### The simulator

Older `ffmpeg_kit_flutter_new` releases shipped no arm64 slice for the
simulator, so the app installed on no Apple Silicon simulator on iOS 26+
("Failed to find matching arch"). The current release (4.6.2) ships an
arm64 simulator slice (its device slice, retagged); this has not been tried
here.
A physical iPhone remains the reference for runtime testing.

Deployment target is iOS 15.0, set in `ios/Podfile`. ffmpeg-kit itself only
needs 14.0; the floor comes from the Flutter version the project is on.

## Device status

Verified on an iPhone 16e running iOS 26.6: the app launches, records (the
camera outputs HEVC), saves with the burned-in date, and VideoToolbox
transcodes to H.264 as the runtime encoder selection intends. Reinstalling over
an existing install kept every video visible, which is the container UUID fix
doing its job.

Two features still fail on device, both with ffmpeg session errors:

- **Subtitles editing.** Saving from the subtitles editor does not produce a
  re-muxed file.
- **Movie generation.** Concatenating a period into a movie fails.

Both are Android-clean and under investigation.

## App Store readiness (Phase 4B, decision D10)

- **Privacy manifest.** `ios/Runner/PrivacyInfo.xcprivacy`, bundled with the
  Runner target: no tracking, no collected data (nothing leaves the phone;
  the place name lookup goes to the system geocoder), and the required-reason
  APIs the app's code and the plugins without a manifest of their own reach:
  UserDefaults `CA92.1` (settings, `shared_preferences`), file timestamps
  `C617.1` (clip, cache and scratch dates in the container; ffmpeg's `stat`,
  `flutter_archive`), disk space `E174.1` (the free-space check before a
  movie, O12; `device_info_plus` reads it on iOS too). No plugin reaches the
  system boot time APIs (`systemUptime`, `mach_absolute_time`); the Flutter
  engine declares its own. The plugins that ship a manifest (camera,
  notifications, photo_manager, permission_handler, shared_preferences and
  the rest) declare their own reasons.
- **Permission prompts.** English in `Info.plist`; translations in
  `ios/Runner/<language>.lproj/InfoPlist.strings`, written by
  `dart run tool/ios/info_plist_strings.dart` from the app's own
  translations, so no prompt is translated by anyone but the translators.
  A prompt a language has not translated falls back to English.
  `CFBundleLocalizations` lists the 12 app languages.

  | prompt (Info.plist key) | translation key | translated in |
  |---|---|---|
  | camera (`NSCameraUsageDescription`) | `cameraPermissionDesc` | all 11 |
  | microphone (`NSMicrophoneUsageDescription`) | `cameraMicPermissionDesc` | all 11 |
  | photo library (`NSPhotoLibraryUsageDescription`) | `galleryPermissionBody` | none yet |
  | location while in use (`NSLocationWhenInUseUsageDescription`) | none | English only |

  iOS has no usage description for notifications. The app never adds to the
  photo library on iOS (the diary lives in `Documents`), so there is no
  `NSPhotoLibraryAddUsageDescription`.
- **Donation links** ("Support the app" in Settings, the coffee and GitHub
  Sponsors buttons) are hidden on iOS (`SettingsPlatform.showsDonationLinks`).
- **ffmpeg-kit** must be switched to LGPL first, see above.
- **Prompts on the archive build.** Install the archive (TestFlight or an
  ad hoc export) and check that recording shows the camera and microphone
  prompts, importing shows the photo library prompt, and turning on
  geotagging shows the location prompt. A permission compiled out of
  permission_handler shows no prompt and reads as "permanently denied".

## Still open

- No export to the system photo library. Sharing a video out of the app uses
  the share sheet, which covers most of the need without asking for
  `NSPhotoLibraryAddUsageDescription`.
- The App Store privacy label (App Store Connect) is filled in by hand. The
  optional error report is an email the user writes and sends from their own
  mail app, with the log attached.
