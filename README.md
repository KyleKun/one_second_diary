<p align="center">
    <img src="/assets/images/app_logo.png" height="250">
</p>


<p align="center">
    <a href="https://github.com/KyleKun"><img src="https://img.shields.io/badge/made%20by-KyleKun-ff6462"></a>
    <a href="https://github.com/KyleKun/one_second_diary/releases/latest"><img src="https://img.shields.io/github/v/release/KyleKun/one_second_diary?label=latest&color=ff6462"></a>
    <a href="https://github.com/sponsors/KyleKun"><img src="https://img.shields.io/github/sponsors/KyleKun?color=ff6462&logo=github-sponsors"></a>
</p>

<p align="center">
     <a href="https://github.com/KyleKun/one_second_diary/blob/main/LICENSE"><img src="https://img.shields.io/github/license/KyleKun/one_second_diary?style=flat"></a>
     <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Made%20with-Flutter-blue.svg"></a>
     <a href="https://github.com/KyleKun/one_second_diary/stargazers"><img src="https://img.shields.io/github/stars/KyleKun/one_second_diary?style=flat"></a>
     <a href="https://github.com/KyleKun/one_second_diary/fork"><img src="https://img.shields.io/github/forks/KyleKun/one_second_diary?style=flat"></a>
     <a href=""><img src="https://img.shields.io/badge/supports-Android%208+-e5b35e"></a>
</p>

<h1 align="center">One Second Diary</h1>

<p align="center">🎬 Record 1 second everyday & create the movie of your life.</p>

<!--
  TODO(owner): screenshots of 2.0.0. Add them to media/ (for example media/v2/1.png … 6.png), then replace this
  comment with the two rows below. The v1.x screenshots (media/1.png … 6.png) show the old design, so they are not
  linked any more.

<p align="center">
    <img src="/media/v2/1.png" width="32%">
    <img src="/media/v2/2.png" width="32%">
    <img src="/media/v2/3.png" width="32%">
</p>
<p align="center">
    <img src="/media/v2/4.png" width="32%">
    <img src="/media/v2/5.png" width="32%">
    <img src="/media/v2/6.png" width="32%">
</p>
-->

## About

This app was inspired by this [TED Talk](https://www.ted.com/talks/cesar_kuriyama_one_second_every_day).

After installing some related apps and not being fully satisfied with any of them, I decided to create my own, featuring the two aspects that I wanted the most: Minimalist and 100% Private. 

Therefore, this app that will never collect any kind of data, display annoying ads or ask you to pay for anything. It's just a simple app that will help you to remember your life.

The idea itself is pretty simple:
 - Open the app in the moment of your day that you would like to remember in the future
 - Record or upload from gallery a short video (2 ~ 10 seconds), or turn a photo into one
 - That's it, open the app the next day and repeat the process

Then, after a couple months or even years:
 - Generate a compilation of all those videos, creating the movie of your life
 
## Download Now

<a href='https://play.google.com/store/apps/details?id=com.kylekun.one_second_diary&pcampaignid=pcampaignidMKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1'><img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png'/></a>

The signed APKs of every version are on the [releases page](https://github.com/KyleKun/one_second_diary/releases).
What changed in each version is in [CHANGELOG.md](CHANGELOG.md).

## Features

Version 2.0.0 is a new app from the ground up: every screen has a new design, and your videos, profiles, movies and
settings carry over as they are.

**Today**
- Record a clip of 2 to 10 seconds in 1080p, with a countdown, pinch to zoom, tap to focus and an orientation lock
- Or add a video from your gallery, or turn a photo into a clip
- Several clips a day, with Undo right after saving
- A greeting for the time of day, with your name if you like

**Edit**
- Trim with quick cuts
- A date stamp in your format and colour
- The place, found automatically or typed by you
- Subtitles

**Diary**
- A calendar with a picture of every day and a small player, instant even with thousands of clips
- Memories: all your days in one scrolling feed
- Full-screen viewer, and share or delete a single clip
- Add a clip to a day you missed

**Journey and movies**
- Your stats: days recorded, streaks, this month, total time recorded and movies made
- Make a movie of a preset range, a month, or clips you pick yourself
- Watch it being made, cancel at any time, then watch it in the app
- My movies: rename, share and delete

**And**
- Profiles to keep videos apart, each with its own photo and orientation
- A daily reminder
- Light and dark themes
- 12 languages: Belarusian, Catalan, Chinese, Czech, English, French, German, Hungarian, Indonesian, Portuguese,
  Russian and Spanish
- Screen readers, large text and reduced motion are supported
- 100% offline: no account, no ads, no tracking. See the [privacy policy](PRIVACY_POLICY.md).

## Platforms

- **Android 8.0 or later** is the shipping platform.
- **iOS 15 or later** builds and runs from the same codebase. What is different there, and the one licensing decision
  an App Store build requires, is written up in [docs/ios.md](docs/ios.md).

## Building from source

You need Flutter 3.47.4 (the version the CI uses), with the Android SDK for Android builds, or Xcode for iOS builds.

```sh
git clone https://github.com/KyleKun/one_second_diary.git
cd one_second_diary
flutter pub get

flutter analyze
flutter test

flutter build apk --release          # Android
flutter build ios --release          # iOS, see docs/ios.md first
```

- A release APK is signed with the key named in `android/key.properties`. Without that file, the build falls back to
  the debug keys, which is fine for trying the app on your own phone but not for publishing.
- Pushing a tag like `v2.0.0` (matching `version:` in `pubspec.yaml`) runs `.github/workflows/release.yml`, which
  builds the signed APKs and publishes a GitHub release with that version's notes from `CHANGELOG.md`.

## Project structure

The app is written in Flutter, with BLoC (Cubits) for state, `get_it` for composition and `go_router` for navigation.

```
lib/
├── main.dart     starts the app
├── app/          bootstrap, the app widget, launch and locale
├── core/         media (ffmpeg), storage, platform gateways, routing, logging, localisation
├── features/     one folder per feature: today, recording, clip_editor, diary, journey, movies,
│                 profiles, settings, reminders, onboarding, clips
├── shared/       the design system's widgets
└── theme/        colours, text styles, sizes and motion
assets/translations/   one JSON file per language
test/             unit, widget and journey tests, mirroring lib/
docs/             ARCHITECTURE.md and ios.md
```

How the layers fit together, how to add a feature and how the tests are written is in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Contributing

Suggestions, bug reports and pull requests are welcome, and so are translations. Read
[CONTRIBUTING.md](CONTRIBUTING.md) first; the people who helped so far are in [CONTRIBUTORS.md](CONTRIBUTORS.md).

## License

One Second Diary is free software under the [GNU General Public License v3.0](LICENSE). You may use, modify and
redistribute it, but any app you distribute that is built from this code must be released under the same license, with
its complete source code and the copyright notices kept.

Versions before 2.0.0 were released under the MIT License; see [NOTICE](NOTICE).

## Support my work

If you like the app, consider becoming a [sponsor](https://github.com/sponsors/KyleKun). It will allow me to stay motivated to work on open-source projects.

Alternatively, you can also make a one-time donation:

[![buymeacoffee](https://user-images.githubusercontent.com/835641/60540201-fcd7fa00-9ce4-11e9-87ec-1e98568e9f58.png)](https://www.buymeacoffee.com/kylekun)
