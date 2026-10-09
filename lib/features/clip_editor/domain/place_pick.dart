import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';

/// What the place sheet gives back: the place [text] (`''` clears it), the
/// [saved] place it is when the user picked one of the saved chips (or
/// typed its name), and whether "Save this place" asked to [save] the text
/// for next time.
final class PlacePick extends Equatable {
  const PlacePick({required this.text, this.saved, this.save = false});

  /// The place, trimmed.
  final String text;

  /// The saved place picked, whose coordinates the clip gets; null for a
  /// place typed by hand or picked from "Recent".
  final SavedPlace? saved;

  /// Whether the editor should save [text] as a place.
  final bool save;

  @override
  List<Object?> get props => <Object?>[text, saved, save];
}
