import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:uuid/uuid.dart';

import '../models/goal.dart';
import '../models/transaction.dart' as app;
import '../models/category.dart' show Category, predefinedCategories;
import '../models/budget.dart';
import '../models/recurring_transaction.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();

  static sql.Database? _database;

  DatabaseService._init();

  Future<sql.Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('foxfunds.db');
    return _database!;
  }

  Future<sql.Database> _initDB(String filePath) async {
    final dbPath = await sql.getDatabasesPath();
    final path = join(dbPath, filePath);

    return await sql.openDatabase(path,
        version: 12, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(
      sql.Database db, int oldVersion, int newVersion) async {
    // Always drop and recreate tables on any version upgrade
    await db.execute('DROP TABLE IF EXISTS goals');
    await db.execute('DROP TABLE IF EXISTS transactions');
    await db.execute('DROP TABLE IF EXISTS budgets');
    await db.execute('DROP TABLE IF EXISTS recurring_transactions');
    await db.execute('DROP TABLE IF EXISTS categories');
    await _createDB(db, newVersion);
  }

  Future<void> _createGoalsTable(sql.Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    await db.execute('''
CREATE TABLE goals (
  id $idType,
  name $textType,
  targetAmount $realType,
  currentAmount $realType
)
''');
  }

  Future<void> _createTransactionsTable(sql.Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const dateTimeType = 'TEXT NOT NULL';
    await db.execute('''
CREATE TABLE transactions (
  id $idType,
  amount $realType,
  categoryId $textType,
  date $dateTimeType,
  description TEXT,
  goalId TEXT
)
''');
  }

  Future<void> _createBudgetTable(sql.Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const realType = 'REAL NOT NULL';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
CREATE TABLE IF NOT EXISTS budgets (
  id $idType,
  amount $realType,
  startDate $textType,
  endDate $textType,
  duration $textType,
  categoryId TEXT
)
''');
  }

  Future<void> _createRecurringTransactionsTable(sql.Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const dateTimeType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    
    await db.execute('''
CREATE TABLE recurring_transactions (
  id $idType,
  amount $realType,
  categoryId $textType,
  description $textType,
  frequency $textType,
  startDate $dateTimeType,
  endDate TEXT,
  isActive $integerType,
  lastProcessedDate TEXT
)
''');
  }

  Future<void> _createCategoriesTable(sql.Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const typeType = 'INTEGER NOT NULL';
    await db.execute('''
CREATE TABLE IF NOT EXISTS categories (
  id $idType,
  name $textType,
  type $typeType
)
''');
  }

  Future _createDB(sql.Database db, int version) async {
    await _createGoalsTable(db);
    await _createTransactionsTable(db);
    await _createBudgetTable(db);
    await _createRecurringTransactionsTable(db);
    await _createCategoriesTable(db); // Ensure categories table is created
    // Seed predefined categories
    for (final category in predefinedCategories) {
      await db.insert('categories', category.toMap(), conflictAlgorithm: sql.ConflictAlgorithm.ignore);
    }
  }

  Future<void> ensureCategorySeed() async {
    final db = await instance.database;
    final count = sql.Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories')) ?? 0;
    if (count == 0) {
      for (final category in predefinedCategories) {
        await db.insert('categories', category.toMap(), conflictAlgorithm: sql.ConflictAlgorithm.ignore);
      }
    }
  }

  // goal CRUD operations
  Future<void> createGoal(Goal goal) async {
    final db = await instance.database;
    await db.insert('goals', goal.toMap());
  }

  Future<Goal> getGoal(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'goals',
      columns: ['id', 'name', 'targetAmount', 'currentAmount'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Goal.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<Goal>> getAllGoals() async {
    final db = await instance.database;
    final result = await db.query('goals');
    return result.map((json) => Goal.fromMap(json)).toList();
  }

  Future<void> updateGoal(Goal goal) async {
    final db = await instance.database;
    await db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<void> deleteGoal(String id) async {
    final db = await instance.database;
    await db.delete(
      'goals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Transaction CRUD operations
  Future<void> createTransaction(app.Transaction newTransaction) async {
    final db = await instance.database;
    await db.insert('transactions', newTransaction.toMap());
  }

  Future<app.Transaction> getTransaction(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return app.Transaction.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<app.Transaction>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((json) => app.Transaction.fromMap(json)).toList();
  }

  Future<void> updateTransaction(app.Transaction transaction) async {
    final db = await instance.database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await instance.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTransactionsForGoal(String goalId) async {
    final db = await instance.database;
    await db.delete(
      'transactions',
      where: 'goalId = ?',
      whereArgs: [goalId],
    );
  }

  // Budget CRUD Operations
  Future<void> createOrUpdateBudget(Budget budget) async {
    final db = await instance.database;
    await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<Budget?> getActiveBudget() async {
    final db = await instance.database;
    final now = DateTime.now();
    // Use a fixed ID to get the single budget record
    final maps = await db.query(
      'budgets',
      where: 'id = ?',
      whereArgs: ['user_main_budget'],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final budget = Budget.fromMap(maps.first);
      // Also check if the budget is still valid for the current date.
      // The check must be inclusive of the start and end dates.
      if (!now.isBefore(budget.startDate) && !now.isAfter(budget.endDate)) {
        return budget;
      }
    }
    return null;
  }

  Future<void> deleteBudget(String id) async {
    final db = await instance.database;
    await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get expenses within a date range, optionally filtered by category
  Future<double> getExpensesInDateRange(DateTime startDate, DateTime endDate, {String? categoryId}) async {
    final db = await instance.database;
    
    String whereClause = 'date >= ? AND date <= ?';
    List<dynamic> whereArgs = [
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ];

    if (categoryId != null) {
      whereClause += ' AND categoryId = ?';
      whereArgs.add(categoryId);
    }

    final result = await db.query(
      'transactions',
      columns: ['amount'],
      where: whereClause,
      whereArgs: whereArgs,
    );

    // Fix: Await the fold operation to ensure sum is double, not FutureOr<double>
    return result.fold<double>(0.0, (sum, row) => sum + (row['amount'] as num).toDouble());
  }

  // Recurring Transaction CRUD operations
  Future<void> createRecurringTransaction(RecurringTransaction recurringTransaction) async {
    final db = await instance.database;
    await db.insert('recurring_transactions', recurringTransaction.toMap());
  }

  Future<RecurringTransaction> getRecurringTransaction(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return RecurringTransaction.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<RecurringTransaction>> getAllRecurringTransactions() async {
    final db = await instance.database;
    final result = await db.query('recurring_transactions');
    return result.map((json) => RecurringTransaction.fromMap(json)).toList();
  }

  Future<List<RecurringTransaction>> getActiveRecurringTransactions() async {
    final db = await instance.database;
    final result = await db.query(
      'recurring_transactions',
      where: 'isActive = ?',
      whereArgs: [1],
    );
    return result.map((json) => RecurringTransaction.fromMap(json)).toList();
  }

  Future<void> updateRecurringTransaction(RecurringTransaction recurringTransaction) async {
    final db = await instance.database;
    await db.update(
      'recurring_transactions',
      recurringTransaction.toMap(),
      where: 'id = ?',
      whereArgs: [recurringTransaction.id],
    );
  }

  Future<void> deleteRecurringTransaction(String id) async {
    final db = await instance.database;
    await db.delete(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Create a transaction for a given recurring item dated now and update its lastProcessedDate
  Future<app.Transaction> processRecurringTransactionNow(RecurringTransaction recurring) async {
    final db = await instance.database; // ensure init
    // Determine description: use recurring.description or category name
    String baseDesc;
    if (recurring.description != null && recurring.description!.trim().isNotEmpty) {
      baseDesc = recurring.description!.trim();
    } else {
      try {
        final cats = await db.query('categories', where: 'id = ?', whereArgs: [recurring.categoryId], limit: 1);
        baseDesc = cats.isNotEmpty ? (cats.first['name'] as String) : '';
      } catch (_) {
        baseDesc = '';
      }
    }

    final txn = app.Transaction(
      id: const Uuid().v4(),
      amount: recurring.amount,
      categoryId: recurring.categoryId,
      date: DateTime.now(),
      description: '[AutoPay] ${baseDesc.isEmpty ? '' : baseDesc}',
    );
    await createTransaction(txn);
    await updateRecurringTransaction(recurring.copyWith(lastProcessedDate: DateTime.now()));
    return txn;
  }

  /// Process all due recurring transactions and create actual transactions
  Future<List<app.Transaction>> processDueRecurringTransactions() async {
    final db = await instance.database; // ensure init
    final recurringTransactions = await getActiveRecurringTransactions();
    final createdTransactions = <app.Transaction>[];

    for (final recurring in recurringTransactions) {
      if (recurring.isDue()) {
        String baseDesc;
        if (recurring.description != null && recurring.description!.trim().isNotEmpty) {
          baseDesc = recurring.description!.trim();
        } else {
          try {
            final cats = await db.query('categories', where: 'id = ?', whereArgs: [recurring.categoryId], limit: 1);
            baseDesc = cats.isNotEmpty ? (cats.first['name'] as String) : '';
          } catch (_) {
            baseDesc = '';
          }
        }

        final transaction = app.Transaction(
          id: const Uuid().v4(),
          amount: recurring.amount,
          categoryId: recurring.categoryId,
          date: DateTime.now(),
          description: '[AutoPay] ${baseDesc.isEmpty ? '' : baseDesc}',
        );

        await createTransaction(transaction);
        createdTransactions.add(transaction);

        final updatedRecurring = recurring.copyWith(lastProcessedDate: DateTime.now());
        await updateRecurringTransaction(updatedRecurring);
      }
    }

    return createdTransactions;
  }

  /// Force recreate the database (use this if you encounter table issues)
  Future<void> forceRecreateDatabase() async {
    final dbPath = await sql.getDatabasesPath();
    final path = join(dbPath, 'foxfunds.db');
    
    // Close existing database connection
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    // Delete the database file
    try {
      await sql.deleteDatabase(path);
    } catch (e) {
      // Ignore errors if file doesn't exist
    }
    
    // Recreate the database
    _database = await _initDB('foxfunds.db');
  }

  // CATEGORY CRUD OPERATIONS
  Future<List<Category>> getAllCategories() async {
    final db = await instance.database;
    final result = await db.query('categories');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  Future<void> createCategory(Category category) async {
    final db = await instance.database;
    await db.insert('categories', category.toMap(), conflictAlgorithm: sql.ConflictAlgorithm.replace);
  }

  Future<void> updateCategory(Category category) async {
    final db = await instance.database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await instance.database;
    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CLEAR ALL DATA
  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('goals');
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('recurring_transactions');
    await db.delete('categories');
    // Re-insert predefined categories
    for (final category in predefinedCategories) {
      await db.insert('categories', category.toMap(), conflictAlgorithm: sql.ConflictAlgorithm.replace);
    }
  }

  // CREATE OR UPDATE RECURRING TRANSACTION
  Future<void> createOrUpdateRecurringTransaction(RecurringTransaction recurringTransaction) async {
    final db = await instance.database;
    await db.insert(
      'recurring_transactions',
      recurringTransaction.toMap(),
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
