import 'package:flutter/foundation.dart';

import 'category.dart';

@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.description,
    this.jarId,
  });

  final String id;
  final double amount;
  final String categoryId;
  final DateTime date;
  final String? description;
  final String? jarId; // if the transaction is to/from a jar

  Transaction copyWith({
    String? id,
    double? amount,
    String? categoryId,
    DateTime? date,
    String? description,
    String? jarId,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      description: description ?? this.description,
      jarId: jarId ?? this.jarId,
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
          jarId == other.jarId;

  @override
  int get hashCode =>
      id.hashCode ^
      amount.hashCode ^
      categoryId.hashCode ^
      date.hashCode ^
      description.hashCode ^
      jarId.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'categoryId': categoryId,
      'date': date.toIso8601String(),
      'description': description,
      'jarId': jarId,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'],
      date: DateTime.parse(map['date']),
      description: map['description'],
      jarId: map['jarId'],
    );
  }
}
