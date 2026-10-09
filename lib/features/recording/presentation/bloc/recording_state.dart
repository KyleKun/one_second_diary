part of 'recording_bloc.dart';

/// Where the camera is.
enum RecordingStatus {
  /// Asking for the camera and the microphone, then opening a lens: the
  /// preview is black and the controls are off.
  opening,

  /// The camera or the microphone is not allowed: a panel explains, and
  /// asks again or opens the settings ([RecordingState.access]).
  needsPermission,

  /// The preview runs and the shutter records.
  ready,

  /// Counting down before recording: [RecordingState.countdown] is the
  /// number shown.
  countingDown,

  recording,

  /// The recording is kept: [RecordingState.handOff] opens the clip editor
  /// in the camera's place.
  done,

  /// The camera couldn't start (the error panel: Try again, or the phone's
  /// camera app).
  failed,

  /// The app is away: the camera is released until it comes back.
  paused,

  /// The phone's camera app records ([RecordingState.systemCamera], or the
  /// error panel's "Use phone's camera app"); the page waits for its file.
  usingSystemCamera,

  /// The phone's camera app was left without a clip, on a page that records
  /// with it: the page closes.
  cancelled,
}

/// Something the camera page says once, in a snackbar, when it happened.
enum RecordingNotice {
  /// Stopped under half a second: dropped ("Too short to save").
  tooShort,

  /// The camera would not start or stop recording ("Couldn't record that
  /// clip"); nothing was kept.
  recordFailed,

  /// The app went away while recording, and the take was dropped
  /// ("Recording stopped"); said once the camera is back.
  interrupted,

  /// Both cameras would not open, or stopped: the camera records with one
  /// ("Dual camera isn't available").
  dualFailed,
}

/// The camera page's state: one per page, from opening the camera to the
/// hand-over to the clip editor.
final class RecordingState extends Equatable {
  const RecordingState({
    required this.status,
    required this.format,
    required this.clipSeconds,
    required this.countdownEnabled,
    required this.orientation,
    this.captureOrientation = DeviceOrientation.portraitUp,
    this.lockedOrientation,
    this.flashOn = false,
    this.lensHasNoLight = false,
    this.countdown,
    this.access,
    this.lens,
    this.lensChoices = const <CameraLens>[],
    this.canSwitchLens = false,
    this.zoom = 1,
    this.focusLocked = false,
    this.session,
    this.handOff,
    this.notice,
    this.systemCamera = false,
    this.microphoneOff = false,
    this.dualSupported = false,
    this.dual = false,
    this.dualLayout = DualCameraLayout.inset,
    this.achieved,
  });

  final RecordingStatus status;

  /// The format of the profile the clip is for: its canvas
  /// is the preview's frame and the words of the lock ("Locked ·
  /// Landscape"), its tier and frame rate what the lens is asked for.
  final ClipFormat format;

  /// The shape of the profile the clip is for.
  VideoOrientation get profileOrientation => format.orientation;

  /// What the lens is asked to capture: the profile's tier and frame rate.
  CaptureQuality get capture => CaptureQuality.of(format);

  /// The picture size the open lens achieved (the sensor's orientation),
  /// which may be below [capture] on a lens that cannot do it; null before
  /// a lens opened, or when the platform did not say. Handed to the editor
  /// with the take.
  final AchievedSize? achieved;

  /// How long the clip is, in seconds (2 to 60).
  final int clipSeconds;

  /// How the phone is held (the UI turns its glyphs to it), settled from
  /// the motion sensor; a recording is made this way unless the lock froze
  /// one.
  final DeviceOrientation orientation;

  /// The orientation the capture is locked to: portrait when a lens opens,
  /// then the way the last recording was made, until a lens opens again.
  /// The plugin turns an Android preview by it, so the page turns the
  /// preview back.
  final DeviceOrientation captureOrientation;

  /// The way the lock keeps the recording, whatever the phone does: the
  /// shape it was locked in, on the side the phone is held. Null while
  /// unlocked ("Auto-rotate"). Starts as the profile's shape and is
  /// remembered per profile (`SettingsRepository.recordingLock`).
  final DeviceOrientation? lockedOrientation;

  /// Whether the flash is wanted: the lens's light stays lit while the
  /// camera is open, on a lens that has one ([canUseFlash]). For this
  /// camera session only.
  final bool flashOn;

  /// Whether the open lens refused its light when asked (an iPhone's ultra
  /// wide or telephoto lens often has none): known only once the flash was
  /// tried on it, then for as long as the page is open.
  final bool lensHasNoLight;

  /// Whether the open lens has a light: a back one (no front lens has one)
  /// that did not refuse it; never with both cameras open. The plugin
  /// can't ask the phone beforehand.
  bool get canUseFlash =>
      !dual && !lensHasNoLight && lens?.facing == CameraFacing.back;

  /// Whether the shutter counts down first.
  final bool countdownEnabled;

  /// The number the countdown shows (3, 2, 1) while
  /// [RecordingStatus.countingDown]; null otherwise.
  final int? countdown;

  /// Whether asking again can help ([AccessOutcome.denied]: "Allow
  /// access") or only the settings can ([AccessOutcome.blocked]: "Open
  /// settings"); null until asked.
  final AccessOutcome? access;

  /// The lens in use (the camera switch's value); null before one opened.
  final CameraLens? lens;

  /// The lenses on the side in use, [lens] among them, in the platform's
  /// order: the settings sheet offers them when there are several.
  final List<CameraLens> lensChoices;

  /// Whether the phone has a lens on the other side (some have one lens
  /// only).
  final bool canSwitchLens;

  /// The zoom of the open lens (1: none), within its range (a pinch starts
  /// from it).
  final double zoom;

  /// Whether the focus and the exposure are held where a long press put
  /// them (the AE/AF lock), until a tap focuses again or a lens opens.
  final bool focusLocked;

  /// The opened lens, whose `preview()` the page shows; null while none is
  /// open.
  final CameraSession? session;

  /// The clip editor on the recording ([RecordingStatus.done]), for the
  /// profile and mode the camera was opened with and the day the take
  /// stopped on (a replace keeps its clip's day). The page opens it in the
  /// camera's place (`pushReplacement`), so the `SavedClip` it pops with
  /// reaches whoever opened the camera.
  final EditClipArgs? handOff;

  /// What the page says about the last recording; cleared when the next
  /// one starts.
  final RecordingNotice? notice;

  /// Whether the page records with the phone's camera app instead of its
  /// own (Android below 10, the "Force native camera" setting): it asks
  /// for the camera only, and never opens a lens.
  final bool systemCamera;

  /// The camera is allowed but the microphone is not: the lens opens
  /// without sound, and a pill says the clips will be silent.
  final bool microphoneOff;

  /// Whether the phone can run its front and back cameras at once (the
  /// settings sheet then offers "Dual camera"); known once the page asked.
  final bool dualSupported;

  /// Whether the page records with both cameras: [session] is then a
  /// `DualCameraSession`, [lens] the camera that leads, and the clip is
  /// always upright. Off again, for this page, when the pair fails.
  final bool dual;

  /// How the two pictures share the clip.
  final DualCameraLayout dualLayout;

  /// A copy with the given fields; the nullable ones take a getter, so
  /// they can be cleared (`notice: () => null`).
  RecordingState copyWith({
    RecordingStatus? status,
    int? clipSeconds,
    bool? countdownEnabled,
    DeviceOrientation? orientation,
    DeviceOrientation? captureOrientation,
    ValueGetter<DeviceOrientation?>? lockedOrientation,
    bool? flashOn,
    bool? lensHasNoLight,
    ValueGetter<int?>? countdown,
    AccessOutcome? access,
    CameraLens? lens,
    List<CameraLens>? lensChoices,
    bool? canSwitchLens,
    double? zoom,
    bool? focusLocked,
    ValueGetter<CameraSession?>? session,
    EditClipArgs? handOff,
    ValueGetter<RecordingNotice?>? notice,
    bool? systemCamera,
    bool? microphoneOff,
    bool? dualSupported,
    bool? dual,
    DualCameraLayout? dualLayout,
    ValueGetter<AchievedSize?>? achieved,
  }) => RecordingState(
    status: status ?? this.status,
    format: format,
    clipSeconds: clipSeconds ?? this.clipSeconds,
    countdownEnabled: countdownEnabled ?? this.countdownEnabled,
    orientation: orientation ?? this.orientation,
    captureOrientation: captureOrientation ?? this.captureOrientation,
    lockedOrientation: lockedOrientation != null
        ? lockedOrientation()
        : this.lockedOrientation,
    flashOn: flashOn ?? this.flashOn,
    lensHasNoLight: lensHasNoLight ?? this.lensHasNoLight,
    countdown: countdown != null ? countdown() : this.countdown,
    access: access ?? this.access,
    lens: lens ?? this.lens,
    lensChoices: lensChoices ?? this.lensChoices,
    canSwitchLens: canSwitchLens ?? this.canSwitchLens,
    zoom: zoom ?? this.zoom,
    focusLocked: focusLocked ?? this.focusLocked,
    session: session != null ? session() : this.session,
    handOff: handOff ?? this.handOff,
    notice: notice != null ? notice() : this.notice,
    systemCamera: systemCamera ?? this.systemCamera,
    microphoneOff: microphoneOff ?? this.microphoneOff,
    dualSupported: dualSupported ?? this.dualSupported,
    dual: dual ?? this.dual,
    dualLayout: dualLayout ?? this.dualLayout,
    achieved: achieved != null ? achieved() : this.achieved,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    format,
    clipSeconds,
    countdownEnabled,
    orientation,
    captureOrientation,
    lockedOrientation,
    flashOn,
    lensHasNoLight,
    countdown,
    access,
    lens,
    lensChoices,
    canSwitchLens,
    zoom,
    focusLocked,
    session,
    handOff,
    notice,
    systemCamera,
    microphoneOff,
    dualSupported,
    dual,
    dualLayout,
    achieved,
  ];
}
