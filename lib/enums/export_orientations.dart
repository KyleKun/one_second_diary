enum ExportOrientation {
  portrait('Portrait', 'portrait'),
  landscape('Landscape', 'landscape');

  final String label;
  final String localizationLabel;

  const ExportOrientation(this.label, this.localizationLabel);
}
