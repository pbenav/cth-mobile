class User {
  final String code;
  final String name;

  const User({
    required this.code,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        code: json['code'] as String,
        name: json['name'] as String,
      );

  @override
  String toString() => 'User(code: $code, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => code.hashCode ^ name.hashCode;
}
