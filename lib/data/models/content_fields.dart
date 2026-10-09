/// Strict content parsing: optional omissions are allowed, malformed values aren't.
class ContentFields {
  const ContentFields(this.json, this.path);
  final Map<String, dynamic> json;
  final String path;

  static Map<String, dynamic> object(Object? value, String path) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$path must be an object');
    }
    return value;
  }

  String string(String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$path.$key must be a non-empty string');
    }
    return value;
  }

  String? optionalString(String key) => json[key] == null ? null : string(key);

  int integer(String key, {int min = 1}) {
    final value = json[key];
    if (value is! int || value < min) {
      throw FormatException('$path.$key must be an integer >= $min');
    }
    return value;
  }

  int? optionalInteger(String key) => json[key] == null ? null : integer(key);

  List<T> list<T>(
    String key,
    T Function(Object?, String) parse, {
    bool optional = false,
  }) {
    final value = json[key];
    if (value == null && optional) return List<T>.unmodifiable([]);
    if (value is! List) throw FormatException('$path.$key must be a list');
    return List<T>.unmodifiable([
      for (var i = 0; i < value.length; i++) parse(value[i], '$path.$key[$i]'),
    ]);
  }

  List<String> strings(String key, {bool optional = false}) =>
      list(key, (value, path) {
        if (value is! String || value.trim().isEmpty) {
          throw FormatException('$path must be a non-empty string');
        }
        return value;
      }, optional: optional);
}
