/// How a preference is stored by the `SharedPreferences` plugin.
enum PrefType { boolean, integer, string, stringList }

/// A typed preference: its exact stored [name], storage [type], and the
/// [defaultValue] a reader gets when the key is absent.
///
/// `T` is nullable for tri-state or optional keys (`bool?` for `showIntro`,
/// `int?` for `sdkVersion`), where "absent" is itself meaningful.
final class PrefKey<T> {
  const PrefKey(this.name, this.type, this.defaultValue);

  final String name;
  final PrefType type;
  final T defaultValue;
}
