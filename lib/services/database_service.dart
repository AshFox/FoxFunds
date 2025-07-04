import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sql;

import '../models/jar.dart';
import '../models/transaction.dart' as app;
import '../models/category.dart';
import '../models/budget.dart';

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
        version: 10, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future<void> _onUpgrade(
      sql.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 10) {
      // Drop all existing tables to recreate them with the new schema
      await db.execute('DROP TABLE IF EXISTS jars');
      await db.execute('DROP TABLE IF EXISTS transactions');
      await db.execute('DROP TABLE IF EXISTS budgets');
      await _createDB(db, newVersion);
    }
  }

  Future<void> _createJarsTable(sql.Database db) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    await db.execute('''
CREATE TABLE jars (
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
  jarId TEXT
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

  Future _createDB(sql.Database db, int version) async {
    await _createJarsTable(db);
    await _createTransactionsTable(db);
    await _createBudgetTable(db);
  }

  // Jar CRUD operations
  Future<void> createJar(Jar jar) async {
    final db = await instance.database;
    await db.insert('jars', jar.toMap());
  }

  Future<Jar> getJar(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'jars',
      columns: ['id', 'name', 'targetAmount', 'currentAmount'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Jar.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<Jar>> getAllJars() async {
    final db = await instance.database;
    final result = await db.query('jars');
    return result.map((json) => Jar.fromMap(json)).toList();
  }

  Future<void> updateJar(Jar jar) async {
    final db = await instance.database;
    await db.update(
      'jars',
      jar.toMap(),
      where: 'id = ?',
      whereArgs: [jar.id],
    );
  }

  Future<void> deleteJar(String id) async {
    final db = await instance.database;
    await db.delete(
      'jars',
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

  Future<void> deleteTransactionsForJar(String jarId) async {
    final db = await instance.database;
    await db.delete(
      'transactions',
      where: 'jarId = ?',
      whereArgs: [jarId],
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

  Future<double> getExpensesInDateRange(DateTime start, DateTime end, {String? categoryId}) async {
    try {
      final db = await instance.database;
      final startDate = start.toIso8601String();
      final endDate = end.toIso8601String();

      // Base query
      String query = '''
        SELECT SUM(amount) as total
        FROM transactions
        WHERE date BETWEEN ? AND ?
      ''';
      List<dynamic> queryArgs = [startDate, endDate];

      // Get all expense category IDs, excluding jar contributions
      final expenseCategoryIds = predefinedCategories
          .where((cat) =>
              cat.type == CategoryType.expense && cat.id != 'jar_contribution')
          .map((cat) => cat.id)
          .toList();
      
      if (expenseCategoryIds.isEmpty) {
        return 0.0;
      }

      // Filter by category
      if (categoryId != null) {
        query += ' AND categoryId = ?';
        queryArgs.add(categoryId);
      } else {
        // If no specific category, sum up all expenses
        query += ' AND categoryId IN (${expenseCategoryIds.map((_) => '?').join(',')})';
        queryArgs.addAll(expenseCategoryIds);
      }


      // Construct the query to sum amounts of expense transactions within the date range
      final result = await db.rawQuery(query, queryArgs);

      if (result.isNotEmpty && result.first['total'] != null) {
        return (result.first['total'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      // If any error occurs (e.g., table not ready, column issues), return 0
      // This prevents the entire home screen from failing to load.
      print('Error in getExpensesInDateRange: $e');
      return 0.0;
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
