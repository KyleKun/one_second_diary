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
bitrate (12 Mbps at 1080p30, see `VideoEncoder.targetBitrateKbps`).

`VideoEncoder` probes `ffmpeg -encoders` once at startup and picks:

| | first choice | fallback |
|---|---|---|
| iOS | `h264_videotoolbox` | `libx264` |
| Android | `libx264` | `h264_mediacodec` |

Because the choice is made at runtime, the project works with either flavour of
the package without a code change:

- **`ffmpeg_kit_flutter_new` (GPL, current default).** Android keeps using
  libx264 and renders exactly what previous releases rendered. iOS uses
  VideoToolbox. Fine for Google Play and for sideloading, **not** distributable
  on the App Store.
- **`ffmpeg_kit_flutter_new_full` (LGPL).** No x264. Android falls back to
  MediaCodec, iOS uses VideoToolbox. This is the flavour an App Store build has
  to use.

To switch, change the dependency in `pubspec.yaml` and the imports at the top of
`lib/utils/ffmpeg_api_wrapper.dart`, which is the only file that names the
package. Nothing else in the app has to change.

Note that ffmpeg-kit is linked dynamically as an `xcframework`, so the LGPL
relinking requirement is satisfied.

## What Android has and iOS does not

- **Start recording with the volume buttons.** iOS gives no supported way to
  intercept the volume buttons, so the shortcut is guarded behind
  `PlatformUtils.isAndroid`.
- **MediaStore.** There is no media index to publish to. `MediaGallery` has a
  sandbox implementation where publishing is a move inside `Documents` and
  deleting is a plain unlink.
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

The unsigned release build runs on every push through
`.github/workflows/ios-compile.yml`.

### The simulator cannot run this app

`ffmpeg_kit_flutter_new` ships no arm64 slice for the simulator, so a
simulator build comes out x86_64 only. Apple Silicon simulators on iOS 26+
no longer execute x86_64 apps (Xcode dropped the Rosetta simulator), which
means the app installs on no current simulator at all: `simctl` rejects it
with "Failed to find matching arch". Device builds are unaffected. Until the
plugin ships an arm64 simulator slice, runtime testing means a physical
iPhone.

Deployment target is iOS 15.0, set in `ios/Podfile`. ffmpeg-kit itself only
needs 14.0; the floor comes from the Flutter version the project is on.

## Still open

- No export to the system photo library. Sharing a video out of the app uses
  the share sheet, which covers most of the need without asking for
  `NSPhotoLibraryAddUsageDescription`.
- Not tested on a physical device by the author of this change. Every claim
  about runtime behaviour above follows from the platform APIs involved, not
  from a device run.
