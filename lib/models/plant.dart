class Plant {
  final int? id;
  final String code;
  final String name;
  final DateTime createdAt;

  Plant({
    this.id,
    required this.code,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Plant.fromMap(Map<String, dynamic> map) {
    return Plant(
      id: map['id'] as int?,
      code: map['code'] as String,
      name: map['name'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Plant copyWith({
    int? id,
    String? code,
    String? name,
    DateTime? createdAt,
  }) {
    return Plant(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
