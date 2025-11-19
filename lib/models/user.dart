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
  id: (json['id'] ?? json['user_id'] ?? json['uid']) as int? ?? 0,
  code: (json['code'] ?? json['user_code'] ?? json['codigo'] ?? json['codigo_usuario']) != null
    ? (json['code'] ?? json['user_code'] ?? json['codigo'] ?? json['codigo_usuario']).toString()
    : '',
  name: (json['name'] ?? json['first_name'] ?? json['given_name'] ?? json['nombre']) != null
    ? (json['name'] ?? json['first_name'] ?? json['given_name'] ?? json['nombre']).toString()
    : '',
  familyName1: (json['family_name1'] ?? json['family_name'] ?? json['last_name'] ?? json['surname'] ?? json['apellido1'] ?? json['apellido'])?.toString(),
  familyName2: (json['family_name2'] ?? json['second_surname'] ?? json['apellido2'] ?? json['apellido_2'])?.toString(),
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
