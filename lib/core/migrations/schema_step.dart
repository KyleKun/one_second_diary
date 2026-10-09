/// One data migration: what [apply] changes to reach [version].
final class SchemaStep {
  const SchemaStep({
    required this.version,
    required this.description,
    required this.apply,
  });

  /// The `osdSchemaVersion` stored once [apply] succeeded.
  final int version;

  /// What the step does, for the log.
  final String description;

  final Future<void> Function() apply;
}
