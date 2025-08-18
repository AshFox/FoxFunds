import 'package:flutter/foundation.dart';

@immutable
class Goal {
  const Goal({
    required this.id,
    required this.name,
    this.targetAmount = 0,
    this.currentAmount = 0,
  });

  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;

  Goal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Goal &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          targetAmount == other.targetAmount &&
          currentAmount == other.currentAmount;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      targetAmount.hashCode ^
      currentAmount.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      name: map['name'],
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num).toDouble(),
    );
  }
}
