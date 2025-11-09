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
    id: (json['id'] ?? json['work_center_id'] ?? json['id_centro']) as int? ?? 0,
    code: (json['code'] ?? json['work_center_code'] ?? json['codigo_centro']) != null
        ? (json['code'] ?? json['work_center_code'] ?? json['codigo_centro']).toString()
        : '',
    name: (json['name'] ?? json['work_center_name'] ?? json['nombre_centro']) != null
        ? (json['name'] ?? json['work_center_name'] ?? json['nombre_centro']).toString()
        : '',
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
