import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';

/// Where the "Show my location" switch is.
enum GeotagStatus {
  /// Off: nothing is looked up (the default).
  off,

  /// On, looking for the place.
  finding,

  /// On, and the place is found.
  found,

  /// On, but no place came back (no fix, or the geocoder is offline): the
  /// switch stays on and the user may type one instead.
  unavailable,

  /// Off: the permission was refused; asking again can still work.
  denied,

  /// Off: the permission can only be granted in the phone's settings.
  blocked,

  /// Off: the phone's location service is switched off.
  serviceOff,
}

/// The clip's location: the switch, the place it found, and a place the user
/// typed or picked instead. [location] is what the clip burns and tags.
final class Geotag extends Equatable {
  const Geotag({
    this.status = GeotagStatus.off,
    this.place,
    this.position,
    this.typed = '',
    this.typedPosition,
    this.asked = false,
    this.removedTyped,
  });

  final GeotagStatus status;

  /// The place found last ("Tokyo, Japan"), kept while the switch is off.
  final String? place;

  /// Where [place] was found.
  final GeoPosition? position;

  /// A place the user typed or picked (`''` for none). It overrides the
  /// switch.
  final String typed;

  /// The coordinates of [typed] when it is a saved place that has some;
  /// null for a place typed by hand.
  final GeoPosition? typedPosition;

  /// Whether the user started the last lookup: a refusal it met is
  /// explained (a dialog), where one met when the editor opened is only
  /// shown on the card.
  final bool asked;

  /// The typed place the switch just replaced, until the next change (the
  /// "Typed location removed" snackbar can put it back).
  final String? removedTyped;

  bool get isOn => switch (status) {
    GeotagStatus.finding ||
    GeotagStatus.found ||
    GeotagStatus.unavailable => true,
    _ => false,
  };

  /// What the clip gets: the typed or picked place (with the coordinates a
  /// saved place carries), the place found with its coordinates, or
  /// nothing.
  ClipLocation get location {
    if (typed.isNotEmpty) {
      return ClipLocation(
        enabled: true,
        text: typed,
        latitude: typedPosition?.latitude,
        longitude: typedPosition?.longitude,
      );
    }
    final GeoPosition? position = this.position;
    if (status == GeotagStatus.found && position != null) {
      return ClipLocation(
        enabled: true,
        text: place,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
    return const ClipLocation.off();
  }

  /// [typedPosition] is given as a function, so it can be cleared (a
  /// typed place has none).
  Geotag copyWith({
    GeotagStatus? status,
    String? place,
    GeoPosition? position,
    String? typed,
    GeoPosition? Function()? typedPosition,
    bool? asked,
  }) => Geotag(
    status: status ?? this.status,
    place: place ?? this.place,
    position: position ?? this.position,
    typed: typed ?? this.typed,
    typedPosition: typedPosition == null ? this.typedPosition : typedPosition(),
    asked: asked ?? this.asked,
  );

  /// This geotag, with [removed] as the typed place the switch replaced.
  Geotag withRemovedTyped(String removed) => Geotag(
    status: status,
    place: place,
    position: position,
    typed: typed,
    typedPosition: typedPosition,
    asked: asked,
    removedTyped: removed,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    place,
    position,
    typed,
    typedPosition,
    asked,
    removedTyped,
  ];
}
