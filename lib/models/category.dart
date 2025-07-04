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
}

final List<Category> predefinedCategories = [
  // Income
  const Category(id: 'salary', name: 'Salary', type: CategoryType.income),
  const Category(id: 'freelance', name: 'Freelance', type: CategoryType.income),
  const Category(
      id: 'investment', name: 'Investment', type: CategoryType.income),
  const Category(id: 'gifts_in', name: 'Gifts', type: CategoryType.income),

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
  const Category(
      id: 'jar_contribution',
      name: 'Jar Contribution',
      type: CategoryType.expense),
];
