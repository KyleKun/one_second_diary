import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/location/location_service.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/storage_space.dart';
import 'package:one_second_diary/features/clip_editor/data/clip_saver.dart';
import 'package:one_second_diary/features/clip_editor/domain/canvas_frame.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_render_plan.dart';
import 'package:one_second_diary/features/clip_editor/domain/edit_clip_draft.dart';
import 'package:one_second_diary/features/clip_editor/domain/geotag.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

/// The clip editor's state: the draft the save needs and where the save is.
///
/// Playback (position, playing) stays in the page: a video tick never
/// reaches this state.
class EditClipCubit extends Cubit<EditClipState> {
  EditClipCubit({
    required EditClipArgs args,
    required this._settings,
    required ClipRepository clips,
    required this._locations,
    required this._savedPlaces,
    required this._metadata,
    required this._saver,
    required this._logger,
  }) : super(_opening(args, _settings, clips));

  /// A photo is ready at once, held for the remembered length; a video
  /// waits for its player to say how long it is. A replace opens on the
  /// replaced clip's tags, as the library knows them, so the new clip
  /// keeps them unless the user edits them here. A recipe
  /// (`EditClipArgs.prefill`, "Edit again") gives the stamp style, the
  /// mute and the framing; its window waits for the source's length.
  static EditClipState _opening(
    EditClipArgs args,
    SettingsRepository settings,
    ClipRepository clips,
  ) {
    final bool photo = args.source is PhotoSource;
    final ClipRecipe? recipe = args.prefill;
    final ClipFrame? recipeFrame = recipe?.frame;
    final EditClipDraft draft = EditClipDraft(
      profile: args.profile,
      length: photo ? HeldPhoto(settings.photoDurationMs.value) : null,
      stamp: recipe?.stampStyle ?? settings.stampStyle.value,
      location: const ClipLocation.off(),
      subtitles: '',
      frame: recipe == null || recipeFrame == null
          ? null
          : CanvasFrame(canvas: recipe.format.orientation, frame: recipeFrame),
      tags: switch (args.mode) {
        ReplaceClip(:final clip) =>
          clips.snapshotOf(clip.profile)?.tagsOf(clip) ?? const <String>[],
        AddClip() => const <String>[],
      },
      mute: !photo && (recipe?.mute ?? false),
    );
    return EditClipState(
      args: args,
      status: photo ? EditClipStatus.ready : EditClipStatus.loading,
      draft: draft,
    );
  }

  final SettingsRepository _settings;
  final LocationService _locations;
  final SavedPlaces _savedPlaces;
  final ClipMetadataCache _metadata;
  final ClipSaver _saver;
  final AppLogger _logger;

  /// The running save's token: Cancel and closing the editor stop it.
  CancelToken? _saving;

  /// Counts the location changes: a lookup answers only the latest one.
  int _geotagRun = 0;

  static const String _tag = 'SAVE';

  /// The video source's player is ready and says it lasts [duration] and is [aspectRatio] (width / height):
  /// the window opens from the start on the length the source calls for, clamped to the file: the camera's setting for an in-app
  /// recording (`EditClipArgs.cameraSeconds`), the last quick cut otherwise; a recipe's window takes its place where it still fits.
  /// A source that reports no length cannot be trimmed or saved.
  void sourceLoaded(Duration duration, {required double aspectRatio}) {
    if (state.status != EditClipStatus.loading) return;
    if (duration <= Duration.zero) {
      emit(state.copyWith(status: EditClipStatus.unplayable));
      return;
    }
    final int? cameraSeconds = state.args.cameraSeconds;
    TrimSelection trim = TrimSelection.initial(
      sourceMs: duration.inMilliseconds,
      lengthMs: cameraSeconds != null
          ? cameraSeconds * 1000
          : _settings.lastQuickCut.value,
    );
    if (state.args.prefill case final ClipRecipe recipe) {
      trim = trim.fitted(startMs: recipe.trimStartMs, endMs: recipe.trimEndMs);
    }
    emit(
      state.copyWith(
        status: EditClipStatus.ready,
        draft: state.draft.copyWith(length: TrimmedVideo(trim)),
        sourceAspectRatio: aspectRatio,
      ),
    );
    unawaited(_readSourceSize(aspectRatio));
  }

  /// The photo source was decoded for the preview: it is [aspectRatio]
  /// (width / height) as shown, which the "fitted to" note compares with
  /// the profile's canvas. A video's shape comes from its player.
  void photoDecoded({required double aspectRatio}) {
    if (state.args.source is! PhotoSource) return;
    if (!aspectRatio.isFinite || aspectRatio <= 0) return;
    final bool first = state.sourceAspectRatio == null;
    emit(state.copyWith(sourceAspectRatio: aspectRatio));
    if (first) unawaited(_readSourceSize(aspectRatio));
  }

  /// Reads the source's pixel size and colour transfer
  /// (`ClipSaver.sourceFacts`), the size upright as the preview shows it
  /// ([aspectRatio] decides which way round), for the framing sheet's
  /// lossless mark, the crop the engine cuts with and the save's range
  /// conversion (an HDR source). A prefilled frame is clamped to the size
  /// once known. Facts that cannot be read leave the state as it is (the
  /// saver logged why).
  Future<void> _readSourceSize(double aspectRatio) async {
    final SourceFacts? probed = await _saver.sourceFacts(
      state.args.source.path,
    );
    if (isClosed || probed == null) return;
    final SourceSize size = (probed.width > probed.height) == (aspectRatio > 1)
        ? (width: probed.width, height: probed.height)
        : (width: probed.height, height: probed.width);
    final CanvasFrame? framed = state.draft.frame;
    final ClipRecipe? recipe = state.args.prefill;
    emit(
      state.copyWith(
        sourceSize: size,
        sourceColorTransfer: probed.colorTransfer,
        draft: framed == null || recipe == null
            ? null
            : state.draft.copyWith(frame: () => _clamped(framed, size, recipe)),
      ),
    );
  }

  /// [framed] kept within what the source of [size] allows on the recipe's
  /// canvas; dropped (default framing) when it is the default once clamped.
  static CanvasFrame? _clamped(
    CanvasFrame framed,
    SourceSize size,
    ClipRecipe recipe,
  ) {
    final ClipFrameGeometry geometry = ClipFrameGeometry(
      sourceWidth: size.width,
      sourceHeight: size.height,
      canvasWidth: recipe.format.width,
      canvasHeight: recipe.format.height,
    );
    final ClipFrame frame = geometry.clamp(framed.frame);
    return geometry.isDefault(frame)
        ? null
        : CanvasFrame(canvas: framed.canvas, frame: frame);
  }

  /// The video source's player could not open it.
  void sourceFailed() {
    if (state.status != EditClipStatus.loading) return;
    emit(state.copyWith(status: EditClipStatus.unplayable));
  }

  /// A finger went down on the trim window or one of its edges.
  void trimStarted() {
    if (state.trim == null || state.trimming) return;
    emit(state.copyWith(trimming: true));
  }

  /// The finger left the trim window.
  void trimEnded() {
    if (!state.trimming) return;
    emit(state.copyWith(trimming: false));
  }

  /// A quick cut chip: the window [lengthMs] long from its start, and the
  /// quick cut the next import opens on (`lastQuickCutMs`). A dragged
  /// handle never changes that. A refused write is logged; the window is
  /// cut all the same.
  Future<void> quickCut(int lengthMs) async {
    if (state.trim == null) return;
    _trim((TrimSelection trim) => trim.withLength(lengthMs));
    try {
      await _settings.lastQuickCut.set(lengthMs);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not remember the quick cut $lengthMs ms',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The window dragged to start at [startMs].
  void windowMoved(int startMs) =>
      _trim((TrimSelection trim) => trim.movedTo(startMs));

  /// The start edge dragged to [startMs].
  void startDragged(int startMs) =>
      _trim((TrimSelection trim) => trim.withStartAt(startMs));

  /// The end edge dragged to [endMs].
  void endDragged(int endMs) =>
      _trim((TrimSelection trim) => trim.withEndAt(endMs));

  void _trim(TrimSelection Function(TrimSelection trim) change) {
    final TrimSelection? trim = state.trim;
    if (trim == null) return;
    emit(
      state.copyWith(
        draft: state.draft.copyWith(length: TrimmedVideo(change(trim))),
      ),
    );
  }

  /// A photo length chip: the photo is held for [durationMs] (one of
  /// `SettingsRepository.photoDurationsMs`), and the next photo starts
  /// there too. A refused write is logged; this photo keeps the length.
  Future<void> photoDurationChanged(int durationMs) async {
    if (state.draft.length is! HeldPhoto) return;
    emit(
      state.copyWith(
        draft: state.draft.copyWith(length: HeldPhoto(durationMs)),
      ),
    );
    try {
      await _settings.photoDurationMs.set(durationMs);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not remember the photo length $durationMs ms',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The profile this clip goes to (this clip only; the app's active
  /// profile stays). A replace stays in the profile of the clip it replaces
  /// (`ClipStore.save` refuses another).
  void profileChanged(ProfileKey profile) {
    if (!state.canChangeProfile) return;
    _edit(state.draft.copyWith(profile: profile));
  }

  /// The date stamp's format, colour and outline, applied at once and
  /// remembered for the next clip. A refused write is logged; this clip
  /// keeps the style.
  Future<void> stampChanged(StampStyle stamp) async {
    _edit(state.draft.copyWith(stamp: stamp));
    try {
      await _settings.stampStyle.set(stamp);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not remember the date stamp',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The framing sheet's frame, made for [canvas] (the canvas of the
  /// clip's profile); null frames the source by default again. Not while
  /// the clip saves.
  void frameChanged(ClipFrame? frame, {required VideoOrientation canvas}) {
    if (state.saving) return;
    final CanvasFrame? kept = frame == null
        ? null
        : CanvasFrame(canvas: canvas, frame: frame);
    _edit(state.draft.copyWith(frame: () => kept));
  }

  /// The framing sheet's fill, remembered for the next clip on a canvas
  /// of [canvas]'s orientation. A refused write is logged.
  Future<void> rememberFill(
    FrameFill fill, {
    required VideoOrientation canvas,
  }) async {
    try {
      await _settings.framingFill(canvas).set(fill);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not remember the ${fill.name} fill',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The fill the framing sheet opens with on [canvas]: the one remembered
  /// (blur on a portrait canvas, black on a landscape one, until changed).
  FrameFill rememberedFill(VideoOrientation canvas) =>
      _settings.framingFill(canvas).value;

  /// The soft subtitle of this clip; `''` for none.
  void subtitlesChanged(String subtitles) =>
      _edit(state.draft.copyWith(subtitles: subtitles));

  /// The tags of this clip, as the tags sheet left them; empty for none.
  void tagsChanged(List<String> tags) =>
      _edit(state.draft.copyWith(tags: List<String>.unmodifiable(tags)));

  /// "Save without sound" switched [mute] on or off (a video source).
  void muteChanged({required bool mute}) =>
      _edit(state.draft.copyWith(mute: mute));

  /// "Slow zoom" switched [zoom] on or off (a photo source).
  void zoomChanged({required bool zoom}) =>
      _edit(state.draft.copyWith(zoom: zoom));

  void _edit(EditClipDraft draft) => emit(state.copyWith(draft: draft));

  /// "Show my location" switched [on] (or off) by the user. On, it looks
  /// for the place, named in [languageCode] (the app language). The switch
  /// is remembered both ways.
  Future<void> geotagSwitched({
    required bool on,
    required String languageCode,
  }) async {
    unawaited(_rememberGeotag(on: on));
    if (!on) {
      _geotagRun++;
      _geotag(state.geotag.copyWith(status: GeotagStatus.off));
      return;
    }
    final String typed = state.geotag.typed;
    await _locate(
      languageCode,
      asked: true,
      replacing: typed.isEmpty ? null : typed,
    );
  }

  /// The place sheet saved [text] (`''` clears it). A typed place is
  /// burned without coordinates and turns the switch off, dropping a place
  /// still being found. The switch goes off for this clip only: the
  /// remembered default stays, since a typed place belongs to the current
  /// clip. Only the user's own switch and a refusal change it.
  void typedPlaceChanged(String text) =>
      _manualPlace(text.trim(), position: null);

  /// The place sheet picked the saved [place]: the clip gets its name and,
  /// when it has them, its coordinates (so the clip is tagged, as a found
  /// place is), with the switch semantics of [typedPlaceChanged]. The
  /// place counts one more use.
  void pickPlace(SavedPlace place) {
    final double? latitude = place.latitude;
    final double? longitude = place.longitude;
    _manualPlace(
      place.name,
      position: latitude != null && longitude != null
          ? GeoPosition(latitude: latitude, longitude: longitude)
          : null,
    );
    unawaited(_touch(place.name));
  }

  /// The place sheet picked [place] from the clips' recent places: a typed
  /// place, without coordinates.
  void pickRecentPlace(String place) => typedPlaceChanged(place);

  void _manualPlace(String typed, {required GeoPosition? position}) {
    final bool wasOn = state.geotag.isOn && typed.isNotEmpty;
    // The switch goes off: a place still being found is not wanted.
    if (wasOn) _geotagRun++;
    _geotag(
      state.geotag.copyWith(
        typed: typed,
        typedPosition: () => position,
        status: wasOn ? GeotagStatus.off : null,
      ),
    );
  }

  /// The places saved, most used first (the place sheet's "Saved" chips).
  List<SavedPlace> savedPlaces() => _savedPlaces.read();

  /// The places the clips carry, most used first, without the ones saved
  /// (the place sheet's "Recent" chips).
  List<String> recentPlaces() {
    final Set<String> saved = <String>{
      for (final SavedPlace place in _savedPlaces.read())
        SavedPlaceName.fold(place.name),
    };
    return <String>[
      for (final ({String place, int count}) recent in _metadata.recentPlaces())
        if (!saved.contains(SavedPlaceName.fold(recent.place))) recent.place,
    ];
  }

  /// Saves the clip's place for next time: the typed place, with the
  /// coordinates of the fix the switch found (the user is there), or the
  /// found place with its own. A place already saved, or none, changes
  /// nothing. [EditClipState.placeSaves] grows once it is saved (the page
  /// says "Place saved"); a store that fails is logged and counted in
  /// [EditClipState.placeSaveFailures].
  Future<void> savePlace() async {
    final Geotag geotag = state.geotag;
    final String name = geotag.typed.isNotEmpty
        ? geotag.typed
        : geotag.status == GeotagStatus.found
        ? geotag.place ?? ''
        : '';
    if (name.isEmpty || _savedPlaces.has(name)) return;
    final GeoPosition? position = geotag.typedPosition ?? geotag.position;
    try {
      await _savedPlaces.add(
        name,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not save the place',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) {
        emit(state.copyWith(placeSaveFailures: state.placeSaveFailures + 1));
      }
      return;
    }
    if (!isClosed) emit(state.copyWith(placeSaves: state.placeSaves + 1));
  }

  Future<void> _touch(String name) async {
    try {
      await _savedPlaces.touch(name);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not count the use of a place',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The editor opened: a switch remembered on looks for the place again.
  /// A refusal is only shown on the card.
  Future<void> locateIfRemembered({required String languageCode}) async {
    if (!_settings.enableGeotagging.value) return;
    await _locate(languageCode, asked: false);
  }

  /// Looks for the place: the switch shows on and finding at once, then
  /// the place or why there is none. A lookup overtaken by another change
  /// of the location is dropped.
  Future<void> _locate(
    String languageCode, {
    required bool asked,
    String? replacing,
  }) async {
    final int run = ++_geotagRun;
    final Geotag finding = state.geotag.copyWith(
      status: GeotagStatus.finding,
      asked: asked,
      typed: '',
      typedPosition: () => null,
    );
    _geotag(replacing == null ? finding : finding.withRemovedTyped(replacing));
    final LocationResult result = await _locations.locate(
      localeIdentifier: languageCode,
    );
    if (isClosed || run != _geotagRun) return;
    switch (result) {
      case LocationFound(:final position, :final placeName):
        _geotag(
          state.geotag.copyWith(
            status: GeotagStatus.found,
            place: placeName,
            position: position,
          ),
        );
      case LocationFailed(:final failure):
        final GeotagStatus status = switch (failure) {
          LocationFailure.permissionDenied => GeotagStatus.denied,
          LocationFailure.permissionBlocked => GeotagStatus.blocked,
          LocationFailure.serviceDisabled => GeotagStatus.serviceOff,
          LocationFailure.noPosition ||
          LocationFailure.offline => GeotagStatus.unavailable,
        };
        _geotag(state.geotag.copyWith(status: status));
        // The switch shows off after a refusal: remember it so.
        if (!state.geotag.isOn) await _rememberGeotag(on: false);
    }
  }

  Future<void> _rememberGeotag({required bool on}) async {
    try {
      await _settings.enableGeotagging.set(on);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not remember the location switch ${on ? 'on' : 'off'}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Shows [geotag] and gives the draft its location.
  void _geotag(Geotag geotag) => emit(
    state.copyWith(
      geotag: geotag,
      draft: state.draft.copyWith(location: geotag.location),
    ),
  );

  /// Save: renders the draft as [look] shows it and files it in the diary,
  /// then ends [SaveStatus.saved] with the clip. Runs only when
  /// [EditClipState.canSave]: a second tap while it runs does nothing. A
  /// save cancelled ends [SaveStatus.idle]; one that failed ends
  /// [SaveStatus.failed] (the saver logged why), with a phone out of space
  /// told apart ([SaveFailure.outOfSpace]).
  Future<void> save(ClipRenderLook look) async {
    if (!state.canSave) return;
    final EditClipArgs args = state.args;
    final EditClipDraft draft = state.draft;
    final CancelToken token = _saving = CancelToken();
    emit(state.copyWith(saveStatus: SaveStatus.rendering, saveProgress: 0));
    try {
      final SavedClip saved = await _saver.save(
        request: ClipRenderPlan.of(
          source: args.source,
          day: args.day,
          mode: args.mode,
          draft: draft,
          legacyStampFont: _settings.legacyStampFont.value,
          look: look,
          sourceSize: state.sourceSize,
          imported: args.imported,
          sourceColorTransfer: state.sourceColorTransfer,
        ),
        source: args.source,
        profile: draft.profile,
        day: args.day,
        mode: args.mode,
        cancelToken: token,
        onProgress: _rendered,
        onPublishing: () => emit(
          state.copyWith(saveStatus: SaveStatus.publishing, saveProgress: 1),
        ),
      );
      if (isClosed) return;
      emit(state.copyWith(saveStatus: SaveStatus.saved, saved: saved));
    } on CancelledException {
      if (isClosed) return;
      emit(state.copyWith(saveStatus: SaveStatus.idle, saveProgress: 0));
    } on StorageShortException catch (error) {
      // Refused before any work (the storage budget): the dialog says how much to free.
      if (isClosed) return;
      emit(
        state.copyWith(
          saveStatus: SaveStatus.failed,
          saveProgress: 0,
          saveFailure: SaveFailure.outOfSpace,
          saveShortfallBytes: () => error.shortfallBytes,
        ),
      );
    } on Object catch (error) {
      // The saver logged why; the diary is as it was.
      if (isClosed) return;
      emit(
        state.copyWith(
          saveStatus: SaveStatus.failed,
          saveProgress: 0,
          // The movie flow's rule for a full phone: ENOSPC from the file
          // system, ffmpeg's log or the gallery's refused copy.
          saveFailure: StorageSpace.isOutOfSpace(error)
              ? SaveFailure.outOfSpace
              : SaveFailure.unexpected,
          saveShortfallBytes: () => null,
        ),
      );
    } finally {
      _saving = null;
    }
  }

  /// The render is [fraction] done (at most ten reports a second). It reads
  /// at most [_renderCap] until the clip is being filed; a report that is
  /// not a number is dropped.
  void _rendered(double fraction) {
    if (isClosed || state.saveStatus != SaveStatus.rendering) return;
    if (fraction.isNaN) return;
    emit(state.copyWith(saveProgress: fraction.clamp(0, _renderCap)));
  }

  static const double _renderCap = .99;

  /// Cancel, while the clip renders: the render stops and leaves no file;
  /// the draft stays for another try. Once the clip is being filed it is
  /// too late, and nothing happens.
  void cancelSave() {
    if (state.saveStatus != SaveStatus.rendering) return;
    _saving?.cancel();
    emit(state.copyWith(saveStatus: SaveStatus.cancelling));
  }

  @override
  Future<void> close() {
    // A render still running stops and leaves no file.
    _saving?.cancel();
    return super.close();
  }

  /// The user left without saving ("Discard"): the source goes when the app
  /// owns it (a recording, a picker copy), never a kept original opened
  /// with "Edit again" (`ClipSource.owned` false).
  Future<void> discard() => _saver.discardSource(state.args.source);
}
