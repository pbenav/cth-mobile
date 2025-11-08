class WorkCenter {
  final int id;
  final String code;
  final String name;

  const WorkCenter({
    required this.id,
    required this.code,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
      };

  factory WorkCenter.fromJson(Map<String, dynamic> json) => WorkCenter(
        id: json['id'] as int? ?? 0,
        code: json['code'] as String,
        name: json['name'] as String,
      );

  @override
  String toString() => 'WorkCenter(id: $id, code: $code, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkCenter &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ code.hashCode ^ name.hashCode;
}
