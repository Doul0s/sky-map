class Constellation {
  final String id;
  final String name;
  final List<List<int>> lines;

  const Constellation({
    required this.id,
    required this.name,
    required this.lines,
  });

  factory Constellation.fromJson(
    Map<String, dynamic> json,
  ) {
    return Constellation(
      id: json['id'] as String,
      name: json['name'] as String,
      lines: (json['lines'] as List)
          .map(
            (line) => (line as List)
                .map((id) => (id as num).toInt())
                .toList(),
          )
          .toList(),
    );
  }
}