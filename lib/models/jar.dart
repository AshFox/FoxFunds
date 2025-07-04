import 'package:flutter/foundation.dart';

@immutable
class Jar {
  const Jar({
    required this.id,
    required this.name,
    this.targetAmount = 0,
    this.currentAmount = 0,
  });

  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;

  Jar copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
  }) {
    return Jar(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Jar &&
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

  factory Jar.fromMap(Map<String, dynamic> map) {
    return Jar(
      id: map['id'],
      name: map['name'],
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num).toDouble(),
    );
  }
}
