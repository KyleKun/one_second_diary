# Architecture

This is the map of One Second Diary 2.0 for contributors: where things live, the rules that keep the app safe for
people who have used it since 2021, and how to add to it. Read [`CONTRIBUTING.md`](../CONTRIBUTING.md) for the pull
request checks and the translation guide.

The 2.0 code was written as "v2" (the design codename). The full record of that rewrite, with every decision, is the
maintainer's working folder `docs/v2/`, which is not part of the repository (it is in `.gitignore`). Where this file
is short, `docs/v2/decisions.md` and `docs/v2/phase3/CONTRACTS.md` there have the details.

- Flutter 3.47.4, Dart 3.13.3.
- State: `flutter_bloc` (cubits by default, a bloc where events must queue).
- Dependencies: `get_it`, used only in the composition files.
- Navigation: `go_router`, wrapped by a typed `AppRoute` enum and typed route arguments.
- Text: `easy_localization`, read through one `Strings` class.
- Media: `ffmpeg_kit`, behind one gateway, with every command built as an argument list.
- No network code, no analytics, no crash reporting. Everything stays on the phone.

## 1. Folders

```
lib/
  main.dart            two lines: import 'package:one_second_diary/app/bootstrap.dart'; void main() => bootstrap();
  app/                 the app root: bootstrap, launch, OsdApp, MaterialApp, locale, wiring between features
  core/                code every feature uses, and every platform interface
  features/<feature>/  one folder per feature: data, domain, presentation, and two composition files
                       (`character` and `clips` have none: what they register is shared, see §3)
  shared/widgets/      the design system's components (Osd* widgets), used by several features
  theme/               design tokens: colours, type, spacing, radii, motion, icons, the ThemeData
assets/
  translations/        one JSON file per language (en.json has every key)
  fonts/, images/      fonts (with their licences) and artwork; flags/ and licenses/ (the ffmpeg-kit GPL text)
test/                  mirrors lib/ and tool/; plus shared/ (harness, robots, fakes, widget helpers) and support/
                       (fakes and seeds)
tool/                  scripts: the icon subset and the notification icon (icons/), the font statics (fonts/),
                       the untranslated-keys report (l10n/), the release-manifest check (android/) and the
                       permission prompts' InfoPlist.strings (ios/)
docs/v2/               the rewrite's record: analysis, design specs, decisions, phase summaries (the
                       maintainer's working notes, not in the repository)
```

### `lib/app`

| Path                                                                                  | What                                                                                                                                                                                                                            |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bootstrap.dart`                                                                      | The entry point `main.dart` calls: the binding, the font licences, then `launchApp`.                                                                                                                                            |
| `bundled_licenses.dart`                                                               | The licences of the bundled fonts and the flag artwork, which bootstrap registers for the licences page.                                                                                                                        |
| `launch/`                                                                             | `launchApp` (what runs before the first frame), `LaunchCubit`, `PostFrameLaunch` (what runs after), the legacy folder migration dialog, `LostPickListener` (a recording Android kept after killing the app), `StorageErrorApp`. |
| `osd_app.dart`                                                                        | The root: provides the app-scoped cubits and blocs and the shared services (see §3).                                                                                                                                            |
| `osd_material_app.dart`, `osd_localization_root.dart`, `platform_reduced_motion.dart` | `MaterialApp.router`, the localisation root, and the fold of iOS Reduce Motion into `disableAnimations` (O17).                                                                                                                  |
| `locale/`                                                                             | Keeps the app language, intl and the reminders in step on a language change.                                                                                                                                                    |
| `wiring/`                                                                             | Small listeners that connect features without them importing each other: the clip library following the active profile, the legacy counters, the reminder plan.                                                                 |

### `lib/core`

| Folder                                          | What                                                                                                                                                                                                             |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `di/`                                           | `injection_container.dart` (`sl`, `registerDependencies`), `LaunchCore` (platform flags, the device language).                                                                                                   |
| `platform/`                                     | **Every interface to a plugin or the OS** (`CameraGateway`, `PickerGateway`, `FfmpegGateway`, `MediaStoreGateway`, `FreeSpaceGateway`, …) and its one real implementation.                                       |
| `media/`                                        | The media engine: `commands/` (ffmpeg argument lists), `policy/` (pure rules: encoder choice, stamp filter, trim, SRT), `types/`, `MediaEngine`, the renderers, the job queue. Pure Dart apart from the gateway. |
| `storage/`                                      | `PrefKeys` (the preferences contract), `PrefsStore`, `LegacyPrefsMirror`, `AppPaths`, `PathNames`, `StorageBudget`.                                                                                             |
| `migrations/`                                   | `SchemaMigrator` and its steps, the legacy Android folder migration, the orphan sweep.                                                                                                                           |
| `router/`                                       | `AppRoute`, `RouteArgs`, `app_router.dart` (the gate and the shell only), `app_shell.dart`, `OsdPages`, `HeroTags`, tab reselect.                                                                               |
| `l10n/`                                         | `Strings`, `OsdLocalization`, `CommonLabels` (labels Flutter already translates), `LocaleFormats`, `DisplayText`.                                                                                                |
| `logging/`                                      | `AppLogger` (tagged lines, a verbose switch), `LogSession` (one file per launch, 7 days kept), the global error handlers, `BugReportService`.                                                                    |
| `permissions/`, `location/`, `time/`, `errors/` | Permission policy and requests, the location service, `LocalDay` and the clock, `AppException`.                                                                                                                  |

### `lib/features`

| Feature       | Screens                                                                                                                                                                                                                                                                               |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `onboarding`  | O1–O5                                                                                                                                                                                                                                                                                 |
| `today`       | T1–T6: the stage (the character and the day's clips), the controls, what the character says (`TodayCharacterCubit`)                                                                                                                                                                   |
| `character`   | no screen of its own: the character's look (a setting), its figure, its speech bubble and its customisation sheet                                                                                                                                                                     |
| `recording`   | the camera, R1–R4                                                                                                                                                                                                                                                                     |
| `clip_editor` | V1–V3, the photo source                                                                                                                                                                                                                                                               |
| `clips`       | no screen of its own: the clip library (index, store, thumbnails, players, import) and the clip UI several screens share (the add-clip flow, the saved snackbar, the subtitle sheet V4, the tags sheets, the private-video flow and its help sheet, mute, Edit again, the imports sheet, `ClipThumbnailView`, `ClipPlayerView`, `ClipHero`), grouped by topic rather than by the layout below |
| `diary`       | D1–D5: the calendar, Memories, the viewer                                                                                                                                                                                                                                             |
| `journey`     | J1 (the stats, the movie card), Places (the globe of where the clips were filmed, its full list) and the clips of one place                                                                                                                                                                          |
| `movies`      | M1–M10 and the movie player                                                                                                                                                                                                                                                           |
| `settings`    | S1, S3, S7–S10, Tags                                                                                                                                                                                                                                                                  |
| `profiles`    | S4–S6                                                                                                                                                                                                                                                                                 |
| `reminders`   | S2                                                                                                                                                                                                                                                                                    |

The screen codes (T1, V2, M6, …) are the design's; `docs/v2/design/spec/` has a spec per area.

Inside a feature:

```
lib/features/<f>/
  <f>_injection.dart   void register<F>(GetIt sl): this feature's registrations
  <f>_routes.dart      this feature's GoRoutes and shell branch
  data/                repositories, stores, services (IO lives here)
  domain/              value types and pure rules (no Flutter where possible)
  presentation/
    cubit/ or bloc/    state (both when a feature has both, as movies)
    pages/             one page per route
    widgets/           one public widget per file
    sheets/, dialogs/  sheets and dialogs (never routes)
```

A feature keeps only the folders it needs (`today` and `character` have no `data/`), and a feature-wide helper
(`TodayMotion`, `CharacterLabels`) sits at the top of `presentation/`.

## 2. Layers and dependency rules

```
presentation (pages, widgets, cubits)
      │ reads state from cubits; cubits call
      ▼
data (repositories, services) ──► domain (value types, pure rules)
      │ talks to the outside only through
      ▼
core/platform interfaces ──► real plugin classes (registered in the container)
```

- **Interfaces live only in `lib/core/platform`.** Everything else is a concrete class. A plugin is imported only by
  its gateway, so a test can fake it and a plugin can be swapped in one file. `ffmpeg_kit` is imported only by
  `ffmpeg_kit_gateway.dart` (`test/core/media/media_imports_guard_test.dart`). One exception: `path_provider` is read
  by `AppPaths.resolve` (`lib/core/storage/app_paths.dart`) and the launch environment
  (`lib/app/launch/launch_environment.dart`), once per launch and before the container exists; tests build
  `AppPaths` directly instead.
- **`core` is the bottom layer, apart from a small shared kernel.** `lib/core` may import the value types every layer
  speaks: `ProfileKey`, `ClipRef`, `ClipNameCodec`, `ClipSource` and `ClipSaveMode`, `ShownPlayer` (a warm player
  handed to the viewer), `MovieSource` and `MoviePreset`, `ClipFilter`, `TagFilter` and `DiaryPlace` (route arguments only),
  `AppLanguage` and `LocaleResolver` (for route arguments,
  hero tags, preference keys, paths and the localisation root). The launch and the legacy migration also take `SettingsRepository` and `ProfilesRepository`, and
  `app_router.dart` spreads each feature's routes. Nothing else in `core` imports a feature.
- **Constructor injection, every dependency `required`.** Services never reach for `sl`.
- **Only the composition files read `sl`:** `injection_container.dart`, `osd_app.dart`, the launch, and each feature's
  `<f>_injection.dart` and `<f>_routes.dart` (`test/core/di/service_locator_guard_test.dart`). Widgets use
  `context.read` / `watch` / `select`.
- **Services that cubits depend on are plain classes, not `final`,** so their tests fake them with
  `extends Fake implements X` (`test/core/fakeable_services_guard_test.dart`). Value types and sealed hierarchies stay
  `final`.
- **Features talk through a small shared surface and explicit hand-offs.** Any feature may use:
  - `clips` (the library and the shared clip UI);
  - the domain types and repositories of `profiles` and `settings`, the domain of `movies` (`MovieSource`, the
    presets and rules) and `DiaryMonth`;
  - the profile pieces of CONTRACTS §7.1 and §8: the app-scoped `ProfilesCubit` and its state, the profile switch
    sheet (T6), `ProfileAvatar`, `ProfileLabels`;
  - the other app-scoped state: `UserNameCubit` (greetings, the saved snackbar) and `MovieJobBloc` (the running
    movie);
  - Report error (`settings/presentation/report_error/`: the cubit, the listener and the no-mail snackbar), which the
    camera, the clip editor and the movie job use too.

  Beyond that, a hand-off is named: Journey reads `MovieRepository` (the movies made), `MoviePosters` and
  `MoviePosterView` (the My movies row), `MovieLabels` and `DiaryOpener` (the Diary on this month, or on a clip's day);
  the Settings tab's reminder row reads `ReminderSettingsCubit` and its preferences read `QuickCuts`; Today shows the
  profiles' `WhatsNewQualityCubit` and its sheet; the camera reads the onboarding's `CameraCapabilityProbe` and the
  editor's `ClipLengthFormat`; onboarding opens the profiles' `QualitySheet`. Other hand-offs go through a route argument
  (`CreateMovieArgs`, `EditClipArgs`), `ProfileSheets`, or a wiring class in `lib/app/wiring`.
  `test/core/feature_imports_guard_test.dart` holds both lists and fails on any other cross-feature import outside
  the composition files; a new one is either routed through the surface or added there with its reason.

- **No synchronous file IO on the UI isolate.** Try the operation and catch `FileSystemException` instead of checking
  `exists()` first; do bulk directory work inside `Isolate.run` (`test/core/ui_isolate_io_guard_test.dart`).
- **Errors are visible.** Catch, log with the area's tag and the stack trace (`AppLogger.warning(tag, message, error:,
stackTrace:)`), then show the user a state or a message. Never swallow an error silently. The logs are what a user
  sends with "Report error".
- `package:` imports everywhere, named arguments for two or more parameters, widget classes instead of `_buildX`
  helpers, one public widget per file. One strict lint set applies to `lib` and `test` (`analysis_options.yaml`).

### Launch order

`launchApp` (`lib/app/launch/launch_app.dart`) does only what the first frame needs, in this order: the portrait
lock, the preference store, the folders (`AppPaths`), this launch's log file and the global error handlers, the theme (D15), the schema
version, the date symbols, the translations and intl's locale, then the container (which builds nothing yet). It then
shows `OsdApp`. Everything else (the media engine, the clip scan, the legacy migration, reminders) starts after the
first frame through `PostFrameLaunch`, kicked off from the widget tree by `LaunchStarter`. The diary folders are never created before onboarding. On an Android phone
without a storage root, only `StorageErrorApp` runs.

## 3. Composition: dependencies and routes

**Dependencies.** `registerDependencies` registers the core services and the platform gateways, then the data
services that several features or the launch share: the profiles repository and the onboarding store, the clip
library (scanner, repository, metadata cache and its backfill, the thumbnail queue and repository, `OriginalsStore`,
`ClipStore`, `ClipSubtitles`, `ClipPrivacy`, `ClipAudio`, `ClipTags`, `TagBatch`, `TagColors`, `SavedPlaces`,
`MediaPublisher`, `ImportFlow`, `ImportProcessor`, the `PlayerPool` factory, the `ProfileConverter` behind
`ProfileConversionStarter`), the movie index, repository and builder, the reminder scheduler, the location service,
the bug report service, the wiring classes and the launch pieces, and the phone check's engine and camera parts
(`DeviceMediaCheckRunner`, `CameraCapabilityProbe`). `clips` has no injection file for that
reason: everything it registers is shared. It then calls each feature's `register<F>(sl)`, which registers what only
that feature uses (its cubits, its own services):

```dart
// lib/features/journey/journey_injection.dart (abridged)
void registerJourney(GetIt sl) {
  sl.registerFactory<JourneyCubit>(
    () => JourneyCubit(profiles: sl(), clips: sl(), clock: sl(), logger: sl() /* … */),
  );
}
```

- A screen cubit is a `registerFactory` (`registerFactoryParam` when it takes route arguments).
- An app-scoped cubit or bloc is a `registerLazySingleton` with `dispose:`, provided in `osd_app.dart`.
- The root provides, for every page: `LaunchCubit`, `ThemeCubit`, `LocaleCubit`, `ProfilesCubit`, `UserNameCubit`,
  `RecoveredClipCubit`, the lazy `MovieJobBloc`, the `WhatsNewQualityCubit` Today reads once, and the shared services
  the clip UI needs (`AppPaths`, `ImportFlow`, `ImportProcessor`, `PermissionRequester`, `ClipRepository`, `ClipStore`,
  `ClipSubtitles`, `ClipPrivacy`, `ClipAudio`, `ClipTags`, `TagColors`, `SavedPlaces`, `ThumbnailRepository`,
  `ProfileFormFactory`, `ConvertProfileFactory`).
- A screen that plays clips gets its own `PlayerPool`, provided in the routes file around the page, which disposes
  it.

**Routes.** `app_router.dart` owns the onboarding gate and the four-tab shell only. It spreads each feature's routes:
`onboardingRoutes()` outside the shell, `todayBranch()`, `diaryBranch()`, `journeyBranch()`, `settingsBranch()`, and
`recordingRoutes()`, `clipEditorRoutes()`, `diaryRoutes()`, `journeyRoutes()`, `moviesRoutes()`, `profilesRoutes()`,
`remindersRoutes()`, `settingsRoutes()`. A page is always built with `OsdPages` and its cubit is provided in the
builder (abridged; the real editor route also provides its `PlayerPool` and picks `fadeThrough` when it takes the
camera's place):

```dart
GoRoute(
  path: AppRoute.editClip.path,
  redirect: requireArgs<EditClipArgs>(orElse: AppRoute.today), // a location without its args
  pageBuilder: (BuildContext context, GoRouterState state) => OsdPages.material(
    state,
    BlocProvider<EditClipCubit>(
      create: (_) => sl<EditClipCubit>(param1: argsOf<EditClipArgs>(state)),
      child: const EditClipPage(key: ValueKey<AppRoute>(AppRoute.editClip)),
    ),
  ),
),
```

## 4. How to add things

### A screen in an existing feature

1. Add the route to `AppRoute` (`lib/core/router/app_route.dart`) with its path. If it takes arguments, add a
   `RouteArgs` subclass in `route_args.dart` and list the route in `needsArguments`.
2. Add the `GoRoute` to the feature's `<f>_routes.dart`: `OsdPages.material` (a normal push), `OsdPages.fadeThrough`
   (a page that takes another's place) or `OsdPages.mediaFlight` (a page media flies into); the page's root key is
   `ValueKey<AppRoute>(route)`; arguments come from `argsOf<T>(state)`, never from casting `state.extra`.
3. Register the page's cubit in `<f>_injection.dart` and provide it in the builder.
4. Build the page from `Osd*` components and tokens (§8). Read text through `Strings` (§7).
5. Test the behaviour: the cubit's logic, and one journey step if the screen is part of a user flow (§11). A sheet or
   a dialog is not a route: show it with `showOsdSheet` / `showOsdDialog`.

### A feature

1. Create `lib/features/<f>/` with `<f>_injection.dart` (`void register<F>(GetIt sl)`) and `<f>_routes.dart`.
2. Call `register<F>(sl)` from `_registerFeatures()` in `injection_container.dart`, and spread its routes (or add its
   branch) in `app_router.dart`. These two lines are the only edits outside the feature folder, unless the feature
   adds a data service that other features or the launch share: that one is registered in `injection_container.dart`
   (§3).
3. Add `test/features/<f>/<f>_injection_test.dart` over `TestContainer` if the registration has a rule worth pinning
   (for example "each tab gets its own cubit").
4. If the feature needs a robot for journeys, add `test/shared/robots/<f>_robot.dart` and expose it from `AppRobot`.

### A gateway (a new plugin or OS call)

A gateway is three classes. Take `FreeSpaceGateway` as the model:

1. **The interface**, in `lib/core/platform/free_space_gateway.dart`: an `abstract interface class` with the smallest
   API the app needs, documented in the app's words (what null means, whether it throws).
2. **The real class**, next to it (`device_info_free_space_gateway.dart`): the only file that imports the plugin.
   It catches the plugin's errors, logs them, and answers as the interface promises.
3. **The fake**, in `test/shared/fakes/` (`FakeFreeSpaceGateway`): scriptable state, no call counting. Register it in
   `FakeGateways` (`test/shared/harness/fake_gateways.dart`) so every journey and `TestContainer` gets it.
4. Register the real class in `injection_container.dart` (`_registerPlatformGateways`).

Journeys call `app.expectNoPluginChannel()`, which fails if anything reached a real plugin: a forgotten fake shows up
there.

## 5. State management

- **Cubit by default.** A screen's cubit holds its state as an immutable `Equatable` class (or a sealed hierarchy),
  derives what it can from the repositories, and never localises: it exposes values and enums, and the widget picks
  the string.
- **A bloc when events must queue or be transformed.** `RecordingBloc` runs every camera command on one queue;
  `MovieJobBloc` is the app-scoped movie job that survives navigation, holds the wakelock and supports cancel.
- **Scope.** A screen's cubit lives as long as its route (or its tab). App-scoped state (`ThemeCubit`, `LocaleCubit`,
  `ProfilesCubit`, `UserNameCubit`, `LaunchCubit`, `MovieJobBloc`) is provided at the root.
- **Rebuild only what changes.** Use `BlocSelector` / `context.select` for a part of the state. The calendar and the
  movie pick list have performance tests that count rebuilds: a tap rebuilds two cells, not the grid.
- **One-shot effects go through listeners,** never through `build`: `BlocListener` (or a small `*Listener` widget such
  as `ReportErrorListener`, `LegacyMigrationListener`, `LostPickListener`, `ProfileFormListener`) shows a snackbar,
  opens a dialog or pops a route when the state changes.
- **Derive, don't synchronise.** The clip index is the one source of truth for what is recorded; Today, the Diary,
  Journey and the movie flow read from it. Repositories expose `watch()` streams; cubits subscribe and close their
  subscriptions in `close()`.
- Dispose everything you create: controllers, subscriptions, timers, `CurvedAnimation`s (a test config under
  `test/features` fails on an undisposed `CurvedAnimation`).

## 6. Navigation

- `AppRoute` is the list of every route. Open a route without arguments with `AppRoute.x.push(context)` or
  `AppRoute.x.go(context)`; a route that needs arguments refuses that (`StateError`) and is opened with its args:
  `EditClipArgs(source: …, day: …, profile: …, mode: …).push<SavedClip>(context)`.
- **Results are typed.** The clip editor pops with a `SavedClip` (or nothing); the opener shows the saved snackbar
  with Undo. The viewer pops with the last `ClipRef` it showed, so the Diary selects that day.
- **Hand-over.** The camera replaces itself with the editor through `RouteArgs.pushReplacement`, which forwards the
  editor's result to whoever opened the camera.
- Tabs are a `StatefulShellRoute` with four branches; tapping the current tab again pops it to its first page and
  tells it through `TabReselectListener`. Hidden tabs run with `TickerMode` off, so players and loops pause.
- Heroes use `OsdHero` with tags from `HeroTags`; a clip's hero is always `ClipHero`.
- Never read `Strings` in a route builder: a language change rebuilds pages in place without calling builders.

## 7. Localisation

- **All text goes through `Strings`** (`lib/core/l10n/strings.dart`), read in `build()`. Each member reads one key of
  `assets/translations/<code>.json`. Cubits, repositories and services never localise.
- **New text goes into `en.json` only**, plus one `Strings` member (decision D7). Translators add it to the other
  files later; until then, easy_localization shows the English text **per key**. Before adding a key, look for an
  existing key that says the same thing, so its translations apply.
- A value with a parameter uses `{name}` placeholders; the member takes named arguments. Compose, don't concatenate:
  `Strings.movieSummary(clips: Strings.clipCount(n), profile: name, orientation: Strings.portrait)`.
- A counted value is a plural object (`one`, `few`, `many`, `other`, per CLDR); its member takes the count first. The
  rules and forms per language are in [`CONTRIBUTING.md`](../CONTRIBUTING.md#translations) (Plurals).
- Labels Flutter already translates (Back, Close, Cancel, Delete, Today, …) come from `CommonLabels.of(context)`
  (decision O3), not from our files.
- Dates and numbers are formatted by the widget with intl; `Intl.defaultLocale` is always the app language. The
  `lang` preference is the source of truth for the language; an unsupported language is never stored.
- `test/core/l10n` checks the files: valid JSON, the same placeholders as `en.json`, the plural forms each language
  needs, and that `Strings` and `en.json` match.

## 8. Design system

- **Tokens** live in `lib/theme` and are exported by `osd_design_system.dart`: `OsdColors` (read through
  `OsdSurface`/the theme so light and dark both work), `OsdTypography` and `OsdFonts`, `OsdSpace`, `OsdRadius`,
  `OsdSizes`, `OsdShadows`, `OsdIcons` (a vendored Material Symbols Rounded subset; add a name with
  `tool/icons/subset_icons.py`), `OsdHaptic`. The source is `docs/v2/design/TOKENS.md` and
  `docs/v2/design/spec/COMPONENTS.md`. Don't write raw colours, sizes or durations in a
  feature.
- **Components** are the `Osd*` widgets in `lib/shared/widgets` (buttons, chrome such as `OsdAppBar`, `OsdSheet`,
  `OsdDialog`, `OsdSnackbar`, controls, surfaces, `OsdHero`, `OsdPressable`, `OsdSpinner`, …), exported by
  `osd_widgets.dart`. A component that serves one screen stays in its feature folder.
- **Motion.** Every duration and curve comes from `OsdMotion` (`fast` 150 ms, `standard` 220 ms, `emphasized`, the
  sheet, carousel and shutter springs, `badgeIn`, …). A feature with its own timings names them in one class (`TodayMotion`,
  `CameraMotion`, …). Animate transforms and opacity, not layout.
- **Reduced motion** is either platform setting (O17). Read it only through `OsdMotion.reduced(context)` or
  `MediaQuery.disableAnimationsOf(context)`. Under reduced motion every animation is instant or a short crossfade,
  idle loops stop and no hero flies.
- **Accessibility.** Tap targets are at least 48 px; text must stay readable at text scale 2.0; a heading is its own
  semantics node; a live value (a recording timer, the movie progress) is a live region.

## 9. Media and ffmpeg: what must never change

Every clip ever saved by One Second Diary must keep working in every later version, and every clip saved now must play
in v1.7. The rules are binding: `docs/v2/analysis/A_ffmpeg.md` §7 (the 43-item checklist) and
`docs/v2/analysis/SYNTHESIS.md` Appendix A (the 20 invariants).

- **Commands are argument lists,** built in `lib/core/media/commands/`, one path per element, never a command
  string. That is what fixed the unquoted `Application Support` paths on iOS.
- **Goldens pin every argument.** `test/core/media/commands/*_test.dart` and `policy/*_test.dart` compare each argv,
  element by element, with literal expected values taken from v1.7. A change that alters an argument fails there. If
  you change one on purpose, write why in the test and in `docs/v2/decisions.md`.
- **The workarounds that must stay** (each has a golden or a behaviour test):
  - the schema marker tag `artist="One Second Diary (v1.5)"`, `album=<profile>`, `comment=origin=…`, and the
    `location` tag format; movies also write `comment=profile=<key>` and the `description` tag (O9);
  - **the format belongs to the profile and is written once** (decision D29, `ClipFormat`: tier 720/1080/1440/2160 ×
    orientation, H.264 or HEVC, 30 or 60 fps, mono or stereo, SDR or HLG; HLG is HEVC only, `ClipFormat.isValid`, and
    `parse` reads `h264-…-hlg` as absent). `clipFormat_<key>` holds it as the canonical string
    (`1080p30-hevc-stereo-sdr`); **absent means today's 1080p H.264 30 fps mono `yuv420p`** (`ClipFormat.legacy`), so
    every clip ever saved keeps its format and every movie stays a stream-copy join. The engine takes a `ClipFormat`
    everywhere (`ClipRenderRequest.format`, `MovieRenderRequest.format`; `orientation` is a getter). HEVC is written
    with `-tag:v hvc1` (Apple players); AAC stays 48 kHz 256 kb/s with the format's channel layout; the canvas is the
    format's (`CanvasFilter.scaleFilter`: pad for landscape, crop for portrait); never `-noautorotate`; never
    stream-copy video on a save;
  - **the encoder per codec and build** (`EncoderCatalog`, listed once): the legacy format keeps today's order (iOS
    VideoToolbox, Android libx264, now `-crf 20 -preset medium`, the one deliberate change to a legacy argv); every
    other H.264 format prefers MediaCodec on Android; HEVC takes `hevc_videotoolbox` / `hevc_mediacodec`, with `-b:v`
    from `EncoderPolicy.bitrateFor` (12000k for the legacy format, as before) and never `-crf`/`-preset`;
  - **the schema marker follows the format**: `artist="One Second Diary (v1.5)"` only for the legacy format,
    `One Second Diary (v2)` for every other (`SaveClipCommand.artistOf`, `osdArtistV2`), so v1.7 normalises those clips
    and never joins them raw. A clip with neither marker is foreign (`ClipSchema.other`: badged "Imported", counted on
    the movie confirmation, processed through the normal save with origin `import`);
  - input-side `-ss`/`-to` in whole milliseconds before the video input; **no end pad** (D29: a save ends exactly at
    the trim end, `ClipTrimPolicy.resolveEndMilliseconds`; the +500 ms pad and the "strict clip length" switch are gone
    and the padded save goldens were rewritten with the reason); the camera records the target + 1 s; clips are 1–60 s;
  - every clip has an audio stream (`anullsrc` for silent videos and photos);
  - the date and place stamps through `textfile=` (never `text=`), the date file with no trailing newline, the
    place file ending in `\r`, **the stamp scaled with the canvas** (`StampFilter.fontSizeFor(format, size)`: the
    `stampSize` preference's base, Small 32 / Medium 40 / Large 48 px on a 1080 short side, scaled by the canvas's
    short side, so Medium is 27/40/53/80 px at 720/1080/1440/2160 and `fontsize=40` on every 1080p clip as before;
    the margin and outline scale likewise), the positions,
    `fontcolor='0xRRGGBB'`, the inverted outline colour,
    `:expansion=none`, and `setFontDirectory` before stamping; the font by what the text's glyphs need
    (`StampFontPolicy`: Rubik, else Noto Sans SC; Yusei Magic first with the legacy stamp font on);
  - a private clip carries `description=private=1` (`ClipPrivacyTag`), written by a stream-copy remux
    (`PrivacyCommands`) or by the save that replaces a private clip; the other tags are never touched. A movie with
    private clips appends `;private=<n>` to its `description`;
  - a tagged clip carries `keywords=<tag>,<tag>` (`KeywordsTag`, the MP4 `keyw` atom; tags sorted by their fold
    key, never a comma inside one), written by the same remux (`KeywordsCommands`) or by the save; an untagged clip
    has no `keywords` tag. A clip saved with "Device info in videos" on carries
    `synopsis=device=…;app=…;recorded=…` (`ClipNotesTag`, which also carries `place=` and `muted=1`); nothing reads it back. A movie made with a tag filter
    appends `;tags=<a>,<b>` and `;without=<c>` to its `description`;
  - subtitles as soft `mov_text` with the default disposition; the SRT input first on saves; the SRT bytes as v1.7
    wrote them, except that no empty line is ever written inside a cue (O6);
  - movies: **the planner decides from facts, never from the marker** (`MoviePlan`): a clip whose probed or cached
    facts (`width`, `height`, `codec`, `fps`, `channels`, `pixelFormat`, `colorTransfer`; `pixelFormat` compared only when
    known, an unknown `colorTransfer` read as SDR, fps within 0.01) differ from the profile's format is normalised on a **copy** in the cache (never the
    original; `NormalizedCopyCache` keys include the format); a clip whose video matches and only whose sound differs
    takes the **audio-only path** (video stream-copied, audio re-encoded into the format's layout). Then the concat
    demuxer `-f concat -safe 0 … -r <fps> -map 0 -c copy`, clips in date and ordinal order, at least 2. The cache's cap
    is `StorageBudget.normalizedCacheCap(free)`: 10 % of free space, never under 512 MiB nor over 8 GiB, read at each
    trim;
  - movies carry MP4 chapters, one per clip joined, from an ffmetadata input on the same concat (`-i <chapters>` after
    the list, `-map_chapters 1` after `-map 0`; `FfmetadataChapters`, D25), titled with the clip's day, place and
    subtitle (`ChapterTitle`); the JSON probe reads them back with `-show_chapters`;
  - every saved clip carries two forced keyframes, 333 ms from each end (`ClipEncoding.forcedKeyframes(ms, fps:)`,
    D27: 10 frames at 30 fps, 20 at 60), and its frame count and keyframe positions are probed into the metadata cache
    (`ProbeCommands.keyframes`, `ClipMeta.keyframes`). **Transitions are time-based** (D29, `TransitionPolicy`:
    `transitionMs` 267, `keyframeMarginMs` 333, 8 and 10 frames at 30 fps, 16 and 20 at 60; its methods take the
    profile's `fps`). A movie made with a transition (`MovieTransition`) copies
    each clip's body between keyframes (`-ss` at the keyframe's time, `-frames:v`), renders only the boundary
    frames with `xfade` (`TransitionCommands`), crossfades the audio in one pass (`acrossfade`, 40-clip chunks)
    and joins everything with `duration` lines in the list; a boundary beside a clip without the keyframes stays a
    hard cut unless the user asks to re-encode older clips into the cache. Without a transition the join is
    byte-identical to before. The movie records `;transition=<fade|black|white>` in its `description`;
  - a muted clip (D28) is a stream-copy remux with a silent track in the audio's place (`MuteCommands`), its
    notes tag saying `muted=1` (`ClipNotesTag`, `ClipMeta.isMuted`); a save can write it that way too
    (`ClipRenderRequest.mute`). Music for a movie (`MovieMusic`, `MusicCommands`: sequence → loop → mix with a
    2 s fade-out) gives the movie TWO audio tracks, the mix first and default, the videos' own sound second
    (`ConcatCommand(secondAudioPath:)`); "music off/on" is a stream-copy swap (`MovieAudioCommands.swap`) and
    `description` carries `music=on|off`. `file_picker` (the system document picker) is behind
    `AudioPickerGateway`, the only file that imports it;
  - **framing** (`PLAN_crop_revamp.md`): a save carries a `SourceFrame` (the `ClipFrame` plus the source size) and
    `CanvasFilter.frameFilter` scales, crops the overflow and pads (even pixels; a blurred copy behind the picture
    through `blurGraph` + `-filter_complex` when the fill is blur); the legacy `crop` filter stays for clips that
    carry a stored crop; a frame that fills the canvas is lossless at the source's own size;
  - **the converter** (`ConvertClipCommand`, "Convert into a new profile"): the finished day clip scaled to the new
    canvas with `-map 0`, `-map_metadata 0`, the `artist` and `album` rewritten, the format's encoder, keyframes and
    pixel format, audio copied when the layout matches (else re-encoded), subtitles copied; the original is never
    touched, a `.osd-conversion.json` manifest in the new folder makes the run resumable;
  - **HDR** (`PLAN_formats.md` §6, built 2026-10-07): an HLG profile writes HEVC Main10 (`-profile:v main10`) on
    `-pix_fmt p010le` (`ClipEncoding.hlgPixelFormat`: VideoToolbox's 10-bit input and the one 10-bit YUV format
    MediaCodec defines) with `-color_primaries bt2020 -color_trc arib-std-b67 -colorspace bt2020nc` and `hvc1`, at
    the HEVC bitrate ×1.2 (`EncoderPolicy`); the stamp is drawn on the 10-bit planes with the same white. **The
    source's probed `color_transfer` decides a conversion in front of the canvas** (`RangeFilter`, carried as
    `ClipRenderRequest.sourceColorTransfer`, `MovieClip.colorTransfer`, the sidecar's `colorTransfer` and the
    recipe's `sourceColorTransfer`; filled by the editor's one probe, `ClipSaver.sourceFacts`, the import
    processor's facts and the converter's sidecar; null is SDR, never a guess at HDR): an HLG source into an HLG
    profile is decoded 10-bit, stamped and encoded as it is (a Dolby Vision 8.4 file keeps its HLG base layer); an
    SDR source into an HLG profile takes `RangeFilter.sdrToHlg` (zimg: linear light with the input tagged BT.709,
    SDR white placed at 75 % HLG through `exposure`, BT.2020, the HLG curve, 10-bit); a PQ source into an HLG
    profile takes `pqToHlg`; an HDR source into ANY SDR profile, the legacy one included, takes the plan's tone
    map, `zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=hable,zscale=t=bt709:m=bt709:r=tv,format=yuv420p`,
    whose `format=yuv420p` keeps libx264 at 8-bit without a legacy argv change. SDR into SDR adds nothing: every
    SDR argv is unchanged, golden by golden. An HLG movie stream-copies HLG clips alone (`MoviePlan.videoMatches`: a
    PQ clip is HDR but not HLG). The in-app camera records SDR (the plugins write 8-bit), so an HLG profile is "for
    imported videos": the picker offers it only when the phone check's HLG encode passed AND the bundled HLG sample
    decoded (`QualityRecommender`), never as the pick, HEVC forced when picked. The HLG argv is verified on a device
    in the lab (`range_filter.dart` lists what);
  - **the phone check** (`CalibrationCommands`, `DeviceMediaCheck`): one second of a lavfi test pattern encoded per
    candidate format with the format's real settings, in escalation order, stopping at the first that fails or runs
    under 0.5× real time, then the two HLG candidates (1080p, and 2160p when 2160p30 HEVC passed), each gated by its
    tier's SDR HEVC test and handed 10-bit frames (`-vf format=yuv420p10le`), passed only when the output probes
    10-bit with the HLG transfer; then the software decode of each bundled sample; its result (`DeviceMediaProfile`,
    `deviceMediaProfile`) feeds `QualityRecommender`;
  - **the storage budget** (`StorageBudget`) is checked before every save, movie, conversion and phone check: the job's
    estimate plus a 200 MB floor against the phone's free space (unknown free space passes); a short verdict refuses
    with the shortfall before any work starts (`StorageShortException` on a save);
  - render into private scratch, publish, and only then remove the old file; delete partial output on failure;
    never delete a user's original picked from the gallery.
- **One file names the ffmpeg package** (`lib/core/platform/ffmpeg_kit_gateway.dart`), so the App Store's LGPL build
  is a one-file switch ([`docs/ios.md`](ios.md)).

## 10. Storage and compatibility with older versions

People update from every version since 1.0, and some go back to 1.7. So:

- **Preferences.** `PrefKeys` (`lib/core/storage/pref_keys.dart`) lists every key with v1.7's exact name, type and
  default, read through the legacy `SharedPreferences` API. Never rename a key, change its type or default, or reuse a
  name in `PrefKeys.deadNeverReuse`. `test/core/storage/pref_keys_golden_test.dart` pins them. A new key is fine;
  add it to `PrefKeys` with a default that means "not set".
- **Downgrade safety.** `LegacyPrefsMirror` keeps writing the keys only v1.x reads (`videoCount`, `movieCount`,
  `dailyEntry`, `today`, `sdkVersion`, the path keys), so v1.7 still opens after 2.0 ran.
- **Files.** A clip is `<videos>/[Profiles/<profile>/]yyyy-MM-dd.mp4`; more clips on the same day are
  `yyyy-MM-dd-2.mp4`, `-3`, … (D1). Dates are never localised. `ClipNameCodec` is the one place that reads and writes
  names. Clips in folders the user made are kept (O1). Movies are `Movies/OSD-Movie-<n>-<yyyy-MM-dd>.mp4`.
- **Paths.** `AppPaths` resolves the folders once per launch. Never persist an absolute path: the iOS container moves
  on every reinstall. Sidecars store paths relative to the videos folder.
- **Private clips.** Whether a clip is private is in its file (the `description` tag above), never in a sidecar of
  its own: `clip_meta_v1.json` mirrors it as derived data and the clip library (`ClipIndex.isPrivate`,
  `ClipIndex.shareable`) is told at launch and on every change (`LibraryWiring`). After a reinstall the marks come
  back as the backfill reads the clips; a movie that leaves private clips out also asks the engine to leave out any
  probed clip whose file says so (`MovieRenderRequest.excludePrivate`).
- **Tags.** A clip's tags are in its file too (the `keywords` tag above): `clip_meta_v1.json` mirrors them (`tags`)
  and the library carries them on every snapshot (`ClipIndex.tagsOf`, `tagCounts`, `filtered(TagFilter)`,
  `where(…)`: a filtered index is a `ClipIndex`, so every range count stays a binary search). The vocabulary is
  derived from the clips, never stored: after a reinstall the tags come back as the backfill reads the clips, and
  a movie made by tag meanwhile may miss clips not read yet (the confirmation says so). `ClipTags` writes a clip's
  tags as `ClipPrivacy` writes its mark (both through `ClipRewriter`: library first, remux, revert on failure);
  `TagBatch` renames, merges or removes a tag across every clip, one rewrite at a time. The only tag state outside
  the files is `tagColors`, the colours chosen in Settings (a JSON preference; a tag without one takes a colour from
  its name).
- **Profiles.** `profiles` holds the labels with Default at index 0 (folder key `''`); each profile's orientation is
  written once, and so is its format (`clipFormat_<key>`, D29; absent or unparsable reads as the legacy format on the
  stored orientation, `orientation_<key>` is still written beside it for older builds). A third per-profile key,
  `recordingLock_<key>` (string, `''`), remembers the camera's orientation lock. All three are removed with the
  profile and sit outside `PrefKeys.all`.
- **Phase 9 keys** (in `PrefKeys.v3`, pinned by the golden; `clipFormat_<key>` above is the per-profile exception): `lastQuickCutMs`
  (int, 1500; written by quick-cut taps only), `framingBlurPortrait` (bool, true), `framingBlurLandscape` (bool,
  false), `deviceMediaProfile` (string, `''`: the phone check's JSON), `keepOriginals` (bool, false), `importKeepWhole`
  (bool, false), `importDateStamp` (bool, true), `whatsNewQuality` (bool, false: set by schema step 2, cleared by the
  sheet), `stampSize` (string, `''`: a `StampSize` token, `small`/`medium`/`large`; `''` or an unknown token reads as
  medium, every clip before it). `strictClipLength` stays listed in `legacyLive` and is **read by nothing** since D29.
- **Originals.** `OneSecondDiary Originals/` beside the diary folder (`AppPaths.originals`, `PathNames.originalsFolder`),
  outside the tree the scanner reads, created on first use with a `.nomedia` file on Android. It holds the user's
  original of a processed import and, with "Keep original recordings" on, every in-app recording, under the clip's
  own relative path (`Profiles/<key>/yyyy-MM-dd.mp4`; ` (2)` on a clash). **The link is the path**: `OriginalsStore`
  lists names only (`ClipIndex.hasSource`), and publish, replace, delete, undo and the privacy remux carry the source
  with the clip. Nothing here is ever deleted except by the user (Settings "Delete originals", the processing sheet).
- **Sidecar.** `clip_meta_v1.json` stays version 1 with additive keys: `fps`, `channels`, `pixelFormat`,
  `colorTransfer`, `schema` (`ClipSchema`: `v15`, `v2`, `other`, from the artist tag) and `recipe` (`ClipRecipe`: trim,
  frame with the source size, stamp style, mute, format; written only for a clip with a kept source, so "Edit again"
  and the converter can re-render it). An absent key reads as unknown and an entry without `schema` (pre-D29) is probed
  whole once more by the backfill; an unknown key is ignored. `ClipOrigin.import` (`comment=origin=import`) marks a
  processed import.
- **Imported clips.** A date-named file without the app's marker (`ClipSchema.other` in the cache) or a date-named
  `.mov`/`.m4v` beside the clips (`ClipScan.foreignFiles`) is foreign: badged, counted, never joined raw until
  processed.
- **Migrations.** Add a data migration as the next `SchemaStep` in `lib/core/migrations/v3_schema_steps.dart`; never
  renumber or remove one. Steps must be idempotent and safe to run after a kill. Step 1 is the v3 baseline; step 2
  (D29) migrates nothing and only sets `whatsNewQuality` on an install that existed before, so Today shows the
  one-time "What's new: quality" sheet (`v3SchemaVersion` is 2).

## 11. Tests

### The policy (owner decision D17)

The suite is kept to **about 1 000 meaningful tests**. The UI will keep changing; the tests must protect users, not
freeze the layout. Before adding a test, ask what user-visible behaviour breaks if it goes red.

**Test:**

- logic: cubits and blocs (state in, state out), policies, planners, counters, date maths across time zones and DST;
- compatibility: preference keys and defaults, file names, folders, migrations, downgrade keys, legacy clips;
- ffmpeg: argument goldens for every command family (one table-driven test per family, not one test per case). Since
  D29 the save goldens are a format matrix (legacy, HEVC 1080p, 4K60 HEVC stereo, 720p, a photo at 60) composed from
  literal pieces, element by element; every legacy argv is byte-identical to v1.7 except the two deliberate changes
  (`-preset medium`, no +500 ms pad), each rewritten with the reason in the test;
- flows: a lean set of robot journeys over the real app with every gateway faked (record, save, undo, the Diary, make
  a movie, profiles, language, onboarding, reminders);
- a bug you fix: first a test that fails for the bug, then the fix;
- performance guards that protect a promise (the calendar and the movie pick list are instant).

**Don't test:**

- sizes, paddings, colours, fonts, radii or widget-tree shapes;
- per-variant renders (every theme × text scale × screen size of the same page);
- what the compiler or the SDK already guarantees (field echoes, `Equatable` equality, `isA` on a declared type);
- a restatement of the code (a test that changes whenever the code changes, whatever the behaviour);
- call counts on collaborators: assert observable state and results.

When your change breaks a test that only pinned a layout detail, delete that test and say so in the pull request.

### How

- Tests mirror `lib/`: `lib/core/x/y.dart` → `test/core/x/y_test.dart`; journeys are in `test/app/journeys/`.
- **Fakes, not mocks.** Never `mocktail` or `mockito`. The fakes are in `test/shared/fakes/` and `test/support/`, and
  `FakeGateways` fakes every gateway.
- **Journeys** use `AppRobot.launch(tester, prefs: …, configureGateways: …)` and the feature robots
  (`app.today`, `app.diary`, `app.movies`, …). Find widgets by key or by semantics, not by position. Settle with
  `settle(tester)`, never `pumpAndSettle` (real pages have endless animations); after real IO, wait with
  `app.harness.settleUntil(() => …)`.
- **Cubit tests** build the cubit directly with fakes (never through `sl`) and use `bloc_test` or plain `expect`s on
  the state.
- **Time.** Use the injected `Clock`, never `DateTime.now()` in `lib`. Anything that depends on the date must pass in
  any time zone; CI runs the suite under UTC, `Europe/Berlin`, `America/New_York` and `America/Santiago`.

## 12. Policy for AI agents

- **Never run the app,** `flutter run`, an emulator, a simulator or a browser. Verify with `dart format`,
  `flutter analyze` and `flutter test` only. Device checks belong to the maintainer
  (`docs/v2/OWNER_CHECKLIST.md`).
- Work test-first: one failing test, the smallest code that passes it, then refactor. Follow the test policy above.
- Run the tests that cover what you changed, not the whole suite, unless asked (`flutter test --concurrency=2
test/features/<f>`).
- The repository may live on an exFAT drive, where macOS creates `._*` files that crash the test loader. Run
  `find lib test tool -name '._*' -type f -delete` before testing, and never commit them.
- Never push, and never commit `._*` files. Keep ffmpeg arguments and preference keys byte-identical unless a
  decision says otherwise.
- Write reports and decisions into `docs/v2/`, where the maintainer reads them (it is not tracked).

## 13. Further reading

- [`docs/ios.md`](ios.md): iOS storage, the encoder, the LGPL build, building.
- In the maintainer's `docs/v2/` (not in the repository): `README.md`, the index of the rewrite's documents;
  `decisions.md`, every owner and orchestrator decision (D1–D29, O1–O24); `phase3/CONTRACTS.md`, routes, arguments, gateways, the
  harness, the shared flows; `phase2/strings_inventory.md`, every string, its key and its screens.
