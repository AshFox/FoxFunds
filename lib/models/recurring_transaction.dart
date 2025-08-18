import 'package:flutter/foundation.dart';

enum RecurringFrequency { monthly, yearly }

@immutable
class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.amount,
    required this.categoryId,
    this.description,
    required this.frequency,
    required this.startDate,
    required this.isActive,
    this.endDate,
    this.lastProcessedDate,
  });

  final String id;
  final double amount;
  final String categoryId;
  final String? description;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime? lastProcessedDate;

  RecurringTransaction copyWith({
    String? id,
    double? amount,
    String? categoryId,
    String? description,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? lastProcessedDate,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          amount == other.amount &&
          categoryId == other.categoryId &&
          description == other.description &&
          frequency == other.frequency &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          isActive == other.isActive &&
          lastProcessedDate == other.lastProcessedDate;

  @override
  int get hashCode =>
      id.hashCode ^
      amount.hashCode ^
      categoryId.hashCode ^
      (description ?? '').hashCode ^
      frequency.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      isActive.hashCode ^
      lastProcessedDate.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'categoryId': categoryId,
      'description': description ?? '',
      'frequency': frequency.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'lastProcessedDate': lastProcessedDate?.toIso8601String(),
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'],
      description: (map['description'] as String?)?.trim().isEmpty == true ? null : map['description'],
      frequency: RecurringFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurringFrequency.monthly,
      ),
      startDate: DateTime.parse(map['startDate']),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      isActive: map['isActive'] == 1,
      lastProcessedDate: map['lastProcessedDate'] != null 
          ? DateTime.parse(map['lastProcessedDate']) 
          : null,
    );
  }

  /// Calculate the next due date based on frequency and last processed date
  DateTime getNextDueDate() {
    final baseDate = lastProcessedDate ?? startDate;
    switch (frequency) {
      case RecurringFrequency.monthly:
        return DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
      case RecurringFrequency.yearly:
        return DateTime(baseDate.year + 1, baseDate.month, baseDate.day);
    }
  }

  /// Check if this recurring transaction is due to be processed
  bool isDue() {
    if (!isActive) return false;
    if (endDate != null && DateTime.now().isAfter(endDate!)) return false;

    final nextDue = getNextDueDate();
    final now = DateTime.now();

    // Consider due if today is the due date (ignoring time) or after the due date
    final isSameDay = now.year == nextDue.year && now.month == nextDue.month && now.day == nextDue.day;
    return now.isAfter(nextDue) || isSameDay;
  }
}