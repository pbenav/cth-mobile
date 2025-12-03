class WorkCenter {
  final int id;
  final String code;
  final String name;
  final String? teamName;

  const WorkCenter({
    required this.id,
    required this.code,
    required this.name,
    this.teamName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'team_name': teamName,
      };

  factory WorkCenter.fromJson(Map<String, dynamic> json) => WorkCenter(
        id: (json['id'] ?? json['work_center_id'] ?? json['id_centro']) as int? ??
            0,
        code: (json['code'] ??
                json['work_center_code'] ??
                json['codigo_centro']) !=
            null
            ? (json['code'] ??
                    json['work_center_code'] ??
                    json['codigo_centro'])
                .toString()
            : '',
        name: (json['name'] ??
                json['work_center_name'] ??
                json['nombre_centro']) !=
            null
            ? (json['name'] ??
                    json['work_center_name'] ??
                    json['nombre_centro'])
                .toString()
            : '',
        teamName: (json['team_name'] ?? json['team'])?.toString(),
      );

  @override
  String toString() =>
      'WorkCenter(id: $id, code: $code, name: $name, teamName: $teamName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkCenter &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name &&
          teamName == other.teamName;

  @override
  int get hashCode =>
      id.hashCode ^ code.hashCode ^ name.hashCode ^ teamName.hashCode;
}
