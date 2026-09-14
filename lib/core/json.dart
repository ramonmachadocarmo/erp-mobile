String asString(Map<String, dynamic> json, String key) =>
    json[key]?.toString() ?? '';

double asDouble(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int asInt(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

bool asBool(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is bool) return v;
  return v?.toString() == 'true';
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return [];
  return [
    for (final e in value)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}
