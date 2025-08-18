import 'package:flutter/foundation.dart';

@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.description,
    this.goalId,
  });

  final String id;
  final double amount;
  final String categoryId;
  final DateTime date;
  final String? description;
  final String? goalId; // if the transaction is to/from a goal

  Transaction copyWith({
    String? id,
    double? amount,
    String? categoryId,
    DateTime? date,
    String? description,
    String? goalId,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      description: description ?? this.description,
      goalId: goalId ?? this.goalId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          amount == other.amount &&
          categoryId == other.categoryId &&
          date == other.date &&
          description == other.description &&
          goalId == other.goalId;

  @override
  int get hashCode =>
      id.hashCode ^
      amount.hashCode ^
      categoryId.hashCode ^
      date.hashCode ^
      description.hashCode ^
      goalId.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'categoryId': categoryId,
      'date': date.toIso8601String(),
      'description': description,
      'goalId': goalId,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'],
      date: DateTime.parse(map['date']),
      description: map['description'],
      goalId: map['goalId'],
    );
  }
}
