class Activity {
  final String title;
  final String subtitle;
  final int progress; // From 0 to 100
  final DateTime date;
  final List<String> tags;

  Activity({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.date,
    this.tags = const [],
  });
}
