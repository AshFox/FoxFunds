import 'package:flutter/foundation.dart';

@immutable
class Budget {
  final String id;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final String duration; // 'weekly' or 'monthly'
  final String? categoryId;

  const Budget({
    required this.id,
    required this.amount,
    required this.startDate,
    required this.endDate,
    required this.duration,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'duration': duration,
      'categoryId': categoryId,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      duration: map['duration'] as String,
      categoryId: map['categoryId'] as String?,
    );
  }
} 