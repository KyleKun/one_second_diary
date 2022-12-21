enum ExportDateRange {
  allTime('All Time'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  last60Days('Last 60 days'),
  last90Days('Last 90 days'),
  thisMonth('This month'),
  thisYear('This year'),
  lastYear('Last year');

  final String label;

  const ExportDateRange(this.label);
}
