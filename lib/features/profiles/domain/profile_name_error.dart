/// Why a profile's display name was rejected. The form owns the localised
/// copy shown for each; the validator only owns the decision.
enum ProfileNameError { empty, invalidCharacters, reserved, duplicate }
