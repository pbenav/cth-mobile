class WorkCenter {
  final String code;
  final String name;

  const WorkCenter({
    required this.code,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
      };

  factory WorkCenter.fromJson(Map<String, dynamic> json) => WorkCenter(
        code: json['code'] as String,
        name: json['name'] as String,
      );

  @override
  String toString() => 'WorkCenter(code: $code, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkCenter &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => code.hashCode ^ name.hashCode;
}
