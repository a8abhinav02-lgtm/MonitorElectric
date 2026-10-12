class Subarea {
  final int? id;
  final int plantId;
  final String name;
  final String category; // 'TRANSFORMER' | 'CIRCUIT_BREAKER'

  Subarea({
    this.id,
    required this.plantId,
    required this.name,
    this.category = 'TRANSFORMER',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'plant_id': plantId,
      'name': name,
      'category': category,
    };
  }

  factory Subarea.fromMap(Map<String, dynamic> map) {
    return Subarea(
      id: map['id'] as int?,
      plantId: map['plant_id'] as int,
      name: map['name'] as String,
      category: (map['category'] as String?) ?? 'TRANSFORMER',
    );
  }

  Subarea copyWith({
    int? id,
    int? plantId,
    String? name,
    String? category,
  }) {
    return Subarea(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      name: name ?? this.name,
      category: category ?? this.category,
    );
  }

  bool get isCircuitBreaker => category == 'CIRCUIT_BREAKER';
  bool get isTransformer => category != 'CIRCUIT_BREAKER';
}
