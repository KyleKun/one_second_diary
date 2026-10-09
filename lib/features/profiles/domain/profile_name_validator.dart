import 'package:one_second_diary/features/profiles/domain/latin_composition.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';

/// The rules for a profile's DISPLAY name. The folder key is separate and
/// immutable (`ProfileFolderKeys`), so a name may use any script or emoji:
/// - blank is empty, checked on the trimmed value;
/// - the English "default" and the localised Default label are reserved,
///   case-insensitively;
/// - names are unique, case-insensitively, after trimming.
///
/// Names are compared in [fold]ed form: invisible format characters (Unicode
/// Cf) are stripped, not rejected (emoji such as 👨‍👩‍👧 are joined by them), and a
/// decomposed accent equals the precomposed letter ([LatinComposition]).
///
/// Control characters (a tab, a line break) are rejected. There is no length
/// rule: the text field limits input to 45 characters.
abstract final class ProfileNameValidator {
  /// Why [rawValue] (as typed) can't be a new display name, or null when it
  /// can. [existingNames] are the names the other profiles show now;
  /// [localizedDefaultLabel] is the Default profile's label in the current
  /// language.
  static ProfileNameError? validate(
    String rawValue, {
    required Iterable<String> existingNames,
    required String localizedDefaultLabel,
  }) {
    final String folded = fold(rawValue);
    if (folded.isEmpty) return ProfileNameError.empty;
    if (_controls.hasMatch(rawValue)) return ProfileNameError.invalidCharacters;
    if (isReserved(rawValue, localizedDefaultLabel: localizedDefaultLabel)) {
      return ProfileNameError.reserved;
    }
    if (existingNames.map(fold).contains(folded)) {
      return ProfileNameError.duplicate;
    }
    return null;
  }

  /// Whether [name] reads as the Default profile's label: `default` in
  /// English or [localizedDefaultLabel], ignoring case and outer spaces.
  static bool isReserved(String name, {required String localizedDefaultLabel}) {
    final String folded = fold(name);
    return folded == 'default' || folded == fold(localizedDefaultLabel);
  }

  /// The form two names are compared in: without format characters,
  /// with decomposed accents composed ([LatinComposition]), trimmed and
  /// lower-cased.
  static String fold(String name) => LatinComposition.compose(
    name.replaceAll(_format, ''),
  ).trim().toLowerCase();

  static final RegExp _format = RegExp(r'\p{Cf}', unicode: true);

  static final RegExp _controls = RegExp(
    r'[\p{Cc}\p{Zl}\p{Zp}]',
    unicode: true,
  );
}
