class Recording {
  const Recording({
    required this.id,
    required this.path,
    required this.recordedAt,
    required this.duration,
  });

  final String id;
  final String path;
  final DateTime recordedAt;
  final Duration duration;
}
