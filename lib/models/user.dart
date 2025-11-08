class User {
  final int id;
  final String code;
  final String name;
  final String? familyName1;
  final String? familyName2;

  const User({
    required this.id,
    required this.code,
    required this.name,
    this.familyName1,
    this.familyName2,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'family_name1': familyName1,
        'family_name2': familyName2,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int? ?? 0,
        code: json['code'] as String,
        name: json['name'] as String,
        familyName1: json['family_name1'] as String?,
        familyName2: json['family_name2'] as String?,
      );

  @override
  String toString() => 'User(id: $id, code: $code, name: $name, familyName1: $familyName1, familyName2: $familyName2)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          familyName1 == other.familyName1 &&
          familyName2 == other.familyName2;

  @override
  int get hashCode => id.hashCode ^ code.hashCode ^ name.hashCode ^ familyName1.hashCode ^ familyName2.hashCode;
}
