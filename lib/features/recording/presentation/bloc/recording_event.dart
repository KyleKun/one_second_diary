part of 'recording_bloc.dart';

/// What the camera page asks of the [RecordingBloc].
sealed class RecordingEvent extends Equatable {
  const RecordingEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The camera page opened: ask for the camera and the microphone, then open
/// the lens.
final class RecordingStarted extends RecordingEvent {
  const RecordingStarted();
}

/// "Allow access" on the permission panel: show the system prompt again.
final class RecordingAccessRequested extends RecordingEvent {
  const RecordingAccessRequested();
}

/// "Open settings" on the permission panel (a permanent refusal): the
/// camera opens when the user comes back with access.
final class RecordingSettingsOpened extends RecordingEvent {
  const RecordingSettingsOpened();
}

/// The app went to the background or came back (the page forwards its
/// `AppLifecycleListener`).
final class RecordingLifecycleChanged extends RecordingEvent {
  const RecordingLifecycleChanged(this.lifecycle);

  final AppLifecycleState lifecycle;

  @override
  List<Object?> get props => <Object?>[lifecycle];
}

/// "Try again" on the error panel: open the camera again.
final class RecordingRetried extends RecordingEvent {
  const RecordingRetried();
}

/// The error panel's "Use phone's camera app": records with it, and hands
/// its file to the clip editor.
final class RecordingSystemCameraRequested extends RecordingEvent {
  const RecordingSystemCameraRequested();
}

/// The camera switch: the other lens, remembered for next time. With both
/// cameras open, the other one leads.
final class RecordingLensSwitched extends RecordingEvent {
  const RecordingLensSwitched();
}

/// The settings sheet's "Lens": another lens on the side in use (wide,
/// ultra wide, telephoto), for this camera only.
final class RecordingLensPicked extends RecordingEvent {
  const RecordingLensPicked(this.lens);

  final CameraLens lens;

  @override
  List<Object?> get props => <Object?>[lens];
}

/// The settings sheet's "Dual camera": records with the front and the back
/// camera at once, or with one again; remembered for the next cameras.
final class RecordingDualToggled extends RecordingEvent {
  const RecordingDualToggled();
}

/// The settings sheet's dual layout tiles: how the two pictures share the
/// clip, remembered too.
final class RecordingDualLayoutChanged extends RecordingEvent {
  const RecordingDualLayoutChanged(this.layout);

  final DualCameraLayout layout;

  @override
  List<Object?> get props => <Object?>[layout];
}

/// The orientation chip or the settings sheet's "Lock orientation": locks
/// the recording to the way the phone is held now, or unlocks it.
final class RecordingLockToggled extends RecordingEvent {
  const RecordingLockToggled();
}

/// The settings sheet's "Flash": turns the lens's light on or off, for this
/// camera only.
final class RecordingFlashToggled extends RecordingEvent {
  const RecordingFlashToggled();
}

/// The clip-length slider, when it is let go: the clip length, for this
/// camera and the next ones (2 to 60 s, `RecordingLengthSteps`).
final class RecordingClipSecondsChanged extends RecordingEvent {
  const RecordingClipSecondsChanged(this.seconds);

  final int seconds;

  @override
  List<Object?> get props => <Object?>[seconds];
}

/// The Countdown switch: turns the countdown before recording on or off.
final class RecordingCountdownToggled extends RecordingEvent {
  const RecordingCountdownToggled();
}

/// A pinch on the preview: zooms to [level] (clamped to the lens's range).
final class RecordingZoomed extends RecordingEvent {
  const RecordingZoomed(this.level);

  final double level;

  @override
  List<Object?> get props => <Object?>[level];
}

/// A tap on the preview: focuses and exposes at [point], in 0..1 of the
/// preview each way, and releases a lock.
final class RecordingFocused extends RecordingEvent {
  const RecordingFocused(this.point);

  final Offset point;

  @override
  List<Object?> get props => <Object?>[point];
}

/// A long press on the preview: focuses and exposes at [point] once and
/// keeps both (the AE/AF lock), until a tap focuses elsewhere.
final class RecordingFocusLocked extends RecordingEvent {
  const RecordingFocusLocked(this.point);

  final Offset point;

  @override
  List<Object?> get props => <Object?>[point];
}

/// The shutter: records, after the countdown when it is on; during the
/// countdown, cancels it.
final class RecordingShutterPressed extends RecordingEvent {
  const RecordingShutterPressed();
}

/// The stop square: stops before the clip length.
final class RecordingStopPressed extends RecordingEvent {
  const RecordingStopPressed();
}

/// Back during a take (the page's `PopScope`): drops the recording or
/// stops the countdown; the camera stays open.
final class RecordingCancelled extends RecordingEvent {
  const RecordingCancelled();
}

/// A volume key was pressed (Android).
final class _VolumeKeyPressed extends RecordingEvent {
  const _VolumeKeyPressed();
}

/// The phone is held [orientation], as the camera counts it
/// ([HeldOrientation]).
final class _OrientationSettled extends RecordingEvent {
  const _OrientationSettled(this.orientation);

  final DeviceOrientation orientation;

  @override
  List<Object?> get props => <Object?>[orientation];
}

/// Both cameras stopped working after they opened.
final class _DualFailed extends RecordingEvent {
  const _DualFailed(this.opening);

  /// Which opening of both cameras it was.
  final int opening;

  @override
  List<Object?> get props => <Object?>[opening];
}

/// The clip length or the countdown setting changed.
final class _SettingsChanged extends RecordingEvent {
  const _SettingsChanged();
}

/// A second of the countdown passed.
final class _CountdownTicked extends RecordingEvent {
  const _CountdownTicked(this.take);

  /// Which countdown of the page the timer was set for.
  final int take;

  @override
  List<Object?> get props => <Object?>[take];
}

/// The recording reached its length ([RecordingTiming.captureOf]).
final class _RecordingTimeUp extends RecordingEvent {
  const _RecordingTimeUp(this.take);

  /// Which recording of the page the timer was set for.
  final int take;

  @override
  List<Object?> get props => <Object?>[take];
}
