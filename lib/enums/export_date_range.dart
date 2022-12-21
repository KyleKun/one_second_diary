enum ExportDateRange {
  allTime('All Time', 'allTime'),
  last7Days('Last 7 days', 'last7Days'),
  last30Days('Last 30 days', 'last30Days'),
  last60Days('Last 60 days', 'last60Days'),
  last90Days('Last 90 days', 'last90Days'),
  thisMonth('This month', 'thisMonth'),
  thisYear('This year', 'thisYear'),
  lastYear('Last year', 'lastYear'),
  custom('Custom', 'custom');

  final String label;
  final String localizationLabel;

  const ExportDateRange(this.label, this.localizationLabel);
}
