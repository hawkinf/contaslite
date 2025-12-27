class Holiday {
  final String date;
  final String name;
  final List<String> types;
  final String? specialNote;

  Holiday({
    required this.date,
    required this.name,
    required this.types,
    this.specialNote,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      date: json['date'] as String,
      name: json['name'] as String,
      types: [(json['type'] as String).replaceAll('national', 'Nacional')],
    );
  }

  Holiday mergeWith(Holiday other) {
    final combinedTypes = {...types, ...other.types}.toList();
    return Holiday(
      date: date,
      name: name,
      types: combinedTypes,
      specialNote: specialNote ?? other.specialNote,
    );
  }
}
