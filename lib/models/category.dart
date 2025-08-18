import 'package:flutter/foundation.dart';

enum CategoryType { income, expense }

@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final CategoryType type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ type.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type == CategoryType.income ? 0 : 1,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      type: (map['type'] as int) == 0 ? CategoryType.income : CategoryType.expense,
    );
  }
}

final List<Category> predefinedCategories = [
  // Income
  const Category(id: 'salary', name: 'Salary', type: CategoryType.income),
  const Category(id: 'freelance', name: 'Freelance', type: CategoryType.income),
  const Category(
      id: 'investment', name: 'Investment', type: CategoryType.income),
  const Category(id: 'gifts_in', name: 'Gifts', type: CategoryType.income),
  const Category(id: 'goal_contribution', name: 'Goal Contribution', type: CategoryType.expense),
  // Expenses
  const Category(id: 'rent', name: 'Rent', type: CategoryType.expense),
  const Category(id: 'utilities', name: 'Utilities', type: CategoryType.expense),
  const Category(id: 'groceries', name: 'Groceries', type: CategoryType.expense),
  const Category(
      id: 'entertainment', name: 'Entertainment', type: CategoryType.expense),
  const Category(
      id: 'transportation',
      name: 'Transportation',
      type: CategoryType.expense),
  const Category(
      id: 'subscriptions', name: 'Subscriptions', type: CategoryType.expense),
  const Category(id: 'other_expense', name: 'Other', type: CategoryType.expense),
];
