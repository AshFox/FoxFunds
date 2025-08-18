import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:foxfunds/models/recurring_transaction.dart';
import 'package:foxfunds/models/transaction.dart';
import 'package:foxfunds/models/goal.dart';
import 'package:foxfunds/models/category.dart';
import 'package:foxfunds/models/budget.dart';
import 'package:foxfunds/services/database_service.dart';
import 'package:foxfunds/services/settings_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart' show Color;


class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  static ExportService get instance => _instance;

  // Helper method to format date and time for filename
  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year.toString();
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    
    return '${year}${month}${day}_${hour}${minute}${second}';
  }

  // Helper method to save file in multiple locations
  Future<List<String>> _saveFileInMultipleLocations(String filename, dynamic content, bool isPdf) async {
    final savedPaths = <String>[];
    try {
      // 1) Always save to app documents directory
      final appDirectory = await getApplicationDocumentsDirectory();
      final appFile = File(p.join(appDirectory.path, filename));
      if (isPdf) {
        await appFile.writeAsBytes(content);
      } else {
        await appFile.writeAsString(content);
      }
      savedPaths.add(appFile.path);

      // 2) Try to save to a public folder: Downloads/foxfund backup (preferred), else Documents/foxfund backup
      Directory? base;
      if (Platform.isAndroid) {
        final downloads = Directory('/storage/emulated/0/Download');
        final documents = Directory('/storage/emulated/0/Documents');
        if (await downloads.exists()) {
          base = downloads;
        } else if (await documents.exists()) {
          base = documents;
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        try {
          base = await getDownloadsDirectory();
        } catch (_) {
          base = null;
        }
        if (base == null) {
          final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
          if (home != null) {
            final downloads = Directory(p.join(home, 'Downloads'));
            final documents = Directory(p.join(home, 'Documents'));
            if (await downloads.exists()) {
              base = downloads;
            } else if (await documents.exists()) {
              base = documents;
            }
          }
        }
      }

      if (base != null) {
        final backupDir = Directory(p.join(base.path, 'foxfund backup'));
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        final publicFile = File(p.join(backupDir.path, filename));
        if (isPdf) {
          await publicFile.writeAsBytes(content, flush: true);
        } else {
          await publicFile.writeAsString(content, flush: true);
        }
        savedPaths.add(publicFile.path);
      }
    } catch (e) {
      // Ignore public save failures; at least app dir has a copy
    }
    return savedPaths;
  }

  // Export data in specified format
  Future<Map<String, dynamic>> exportData({
    required String type,
    required String format,
  }) async {
    try {
      String content = '';
      String filename = '';
      String message = '';

      switch (format.toLowerCase()) {
        case 'csv':
          content = await _exportToCSV(type);
          filename = 'foxfunds_backup_${_formatDateTime(DateTime.now())}.csv';
          message = 'CSV exported successfully';
          break;
        case 'pdf':
          final pdfBytes = await _exportToPDF(type);
          content = 'pdf'; // Placeholder for PDF bytes
          filename = 'foxfunds_backup_${_formatDateTime(DateTime.now())}.pdf';
          message = 'PDF exported successfully';
          
          // Save PDF file in multiple locations
          final savedPaths = await _saveFileInMultipleLocations(filename, pdfBytes, true);
          
          // Open the first saved file
          if (savedPaths.isNotEmpty) {
            await OpenFile.open(savedPaths.first);
          }
          
          return {
            'success': true,
            'message': message,
            'filename': filename,
            'filePath': savedPaths.first,
            'allPaths': savedPaths,
          };
        default:
          return {
            'success': false,
            'message': 'Unsupported format: $format',
          };
      }

      // Save CSV file in multiple locations
      final savedPaths = await _saveFileInMultipleLocations(filename, content, false);

      return {
        'success': true,
        'message': message,
        'filename': filename,
        'filePath': savedPaths.first,
        'allPaths': savedPaths,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Export failed: $e',
      };
    }
  }

  // Export transactions to CSV
  Future<String> exportTransactionsToCSV() async {
    final transactions = await DatabaseService.instance.getAllTransactions();
    
    String csvContent = 'Type,Amount,Category,Description,Date\n';
    
    for (final transaction in transactions) {
      final category = predefinedCategories.firstWhere(
        (cat) => cat.id == transaction.categoryId,
        orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
      );
      
      final type = category.type == CategoryType.income ? 'Income' : 'Expense';
      final amount = SettingsService.instance.formatCurrency(transaction.amount);
      final date = '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}-${transaction.date.day.toString().padLeft(2, '0')}';
      
      csvContent += '${type},${amount},"${category.name}","${transaction.description ?? ''}",${date}\n';
    }
    
    return csvContent;
  }

  // Export goals to CSV
  Future<String> exportGoalsToCSV() async {
    final goals = await DatabaseService.instance.getAllGoals();
    
    String csvContent = 'Name,Target Amount,Current Amount,Progress\n';
    
    for (final goal in goals) {
      final progress = goal.targetAmount > 0 ? (goal.currentAmount / goal.targetAmount * 100).toStringAsFixed(1) : '0.0';
      final targetAmount = SettingsService.instance.formatCurrency(goal.targetAmount);
      final currentAmount = SettingsService.instance.formatCurrency(goal.currentAmount);
      
      csvContent += '"${goal.name}",${targetAmount},${currentAmount},${progress}%\n';
    }
    
    return csvContent;
  }

  // Export categories to CSV
  Future<String> exportCategoriesToCSV() async {
    final categories = await DatabaseService.instance.getAllCategories();
    
    String csvContent = 'Name,Type\n';
    
    for (final category in categories) {
      final type = category.type == CategoryType.income ? 'Income' : 'Expense';
      csvContent += '"${category.name}",${type}\n';
    }
    
    return csvContent;
  }

  // Export budget to CSV
  Future<String> exportBudgetToCSV() async {
    final budget = await DatabaseService.instance.getActiveBudget();
    
    if (budget == null) {
      return 'No active budget found';
    }
    
    final categories = await DatabaseService.instance.getAllCategories();
    final categoryName = budget.categoryId != null 
        ? categories.firstWhere(
            (cat) => cat.id == budget.categoryId,
            orElse: () => const Category(id: 'unknown', name: 'All Categories', type: CategoryType.expense),
          ).name
        : 'All Categories';
    
    String csvContent = 'Amount,Duration,Category,Start Date,End Date\n';
    final amount = SettingsService.instance.formatCurrency(budget.amount);
    final startDate = '${budget.startDate.year}-${budget.startDate.month.toString().padLeft(2, '0')}-${budget.startDate.day.toString().padLeft(2, '0')}';
    final endDate = '${budget.endDate.year}-${budget.endDate.month.toString().padLeft(2, '0')}-${budget.endDate.day.toString().padLeft(2, '0')}';
    
    csvContent += '${amount},${budget.duration},"${categoryName}",${startDate},${endDate}\n';
    
    return csvContent;
  }

  // Export all data to CSV
  Future<String> exportAllDataToCSV() async {
    final transactions = await exportTransactionsToCSV();
    final goals = await exportGoalsToCSV();
    final categories = await exportCategoriesToCSV();
    final budget = await exportBudgetToCSV();
    
    return '=== TRANSACTIONS ===\n$transactions\n=== GOALS ===\n$goals\n=== CATEGORIES ===\n$categories\n=== BUDGET ===\n$budget';
  }

  // Export transactions to PDF
  Future<Uint8List> exportTransactionsToPDF() async {
    final transactions = await DatabaseService.instance.getAllTransactions();
    
    final pdf = pw.Document();
    
    // Create table data
    final tableData = <List<String>>[];
    tableData.add(['Type', 'Amount', 'Category', 'Description', 'Date']);
    
    // Sort transactions by date (newest first)
    final sortedTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    for (final transaction in sortedTransactions) {
      final category = predefinedCategories.firstWhere(
        (cat) => cat.id == transaction.categoryId,
        orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
      );
      
      final type = category.type == CategoryType.income ? 'Income' : 'Expense';
      final amount = SettingsService.instance.formatCurrency(transaction.amount);
      final date = '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}-${transaction.date.day.toString().padLeft(2, '0')}';
      
      tableData.add([
        type,
        amount,
        category.name,
        transaction.description ?? category.name,
        date,
      ]);
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FoxFunds - Transaction History',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                },
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }

  // Export goals to PDF
  Future<Uint8List> exportGoalsToPDF() async {
    final goals = await DatabaseService.instance.getAllGoals();
    
    final pdf = pw.Document();
    
    // Create table data
    final tableData = <List<String>>[];
    tableData.add(['Name', 'Target Amount', 'Current Amount', 'Progress']);
    
    // Sort goals by name
    final sortedGoals = List<Goal>.from(goals)
      ..sort((a, b) => a.name.compareTo(b.name));
    
    for (final goal in sortedGoals) {
      final progress = goal.targetAmount > 0 ? '${(goal.currentAmount / goal.targetAmount * 100).toStringAsFixed(1)}%' : '0.0%';
      final targetAmount = SettingsService.instance.formatCurrency(goal.targetAmount);
      final currentAmount = SettingsService.instance.formatCurrency(goal.currentAmount);
      
      tableData.add([
        goal.name,
        targetAmount,
        currentAmount,
        progress,
      ]);
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FoxFunds - Goals',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.center,
                },
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }

  // Export categories to PDF
  Future<Uint8List> exportCategoriesToPDF() async {
    final categories = await DatabaseService.instance.getAllCategories();
    
    final pdf = pw.Document();
    
    // Create table data
    final tableData = <List<String>>[];
    tableData.add(['Name', 'Type']);
    
    // Sort categories by name
    final sortedCategories = List<Category>.from(categories)
      ..sort((a, b) => a.name.compareTo(b.name));
    
    for (final category in sortedCategories) {
      final type = category.type == CategoryType.income ? 'Income' : 'Expense';
      
      tableData.add([
        category.name,
        type,
      ]);
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FoxFunds - Categories',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                },
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }

  // Export budget to PDF
  Future<Uint8List> exportBudgetToPDF() async {
    final budget = await DatabaseService.instance.getActiveBudget();
    
    final pdf = pw.Document();
    
    if (budget == null) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FoxFunds - Budget',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'No active budget found',
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ],
            );
          },
        ),
      );
      return pdf.save();
    }
    
    final categories = await DatabaseService.instance.getAllCategories();
    final categoryName = budget.categoryId != null 
        ? categories.firstWhere(
            (cat) => cat.id == budget.categoryId,
            orElse: () => const Category(id: 'unknown', name: 'All Categories', type: CategoryType.expense),
          ).name
        : 'All Categories';
    
    // Create table data
    final tableData = <List<String>>[];
    tableData.add(['Amount', 'Duration', 'Category', 'Start Date', 'End Date']);
    
    final amount = SettingsService.instance.formatCurrency(budget.amount);
    final startDate = '${budget.startDate.year}-${budget.startDate.month.toString().padLeft(2, '0')}-${budget.startDate.day.toString().padLeft(2, '0')}';
    final endDate = '${budget.endDate.year}-${budget.endDate.month.toString().padLeft(2, '0')}-${budget.endDate.day.toString().padLeft(2, '0')}';
    
    tableData.add([
      amount,
      budget.duration,
      categoryName,
      startDate,
      endDate,
    ]);
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FoxFunds - Budget',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerRight,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                },
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }

  // Export all data to PDF
  Future<Uint8List> exportAllDataToPDF() async {
    final transactions = await DatabaseService.instance.getAllTransactions();
    final goals = await DatabaseService.instance.getAllGoals();
    
    final pdf = pw.Document();
    
    // Transactions table
    final transactionData = <List<String>>[];
    transactionData.add(['Type', 'Amount', 'Category', 'Description', 'Date']);
    
    // Sort transactions by date (newest first)
    final sortedTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    for (final transaction in sortedTransactions) {
      final category = predefinedCategories.firstWhere(
        (cat) => cat.id == transaction.categoryId,
        orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
      );
      
      final type = category.type == CategoryType.income ? 'Income' : 'Expense';
      final amount = SettingsService.instance.formatCurrency(transaction.amount);
      final date = '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}-${transaction.date.day.toString().padLeft(2, '0')}';
      
      transactionData.add([
        type,
        amount,
        category.name,
        transaction.description ?? category.name,
        date,
      ]);
    }
    
    // Goals table
    final goalData = <List<String>>[];
    goalData.add(['Name', 'Target Amount', 'Current Amount', 'Progress']);
    
    // Sort goals by name
    final sortedGoals = List<Goal>.from(goals)
      ..sort((a, b) => a.name.compareTo(b.name));
    
    for (final goal in sortedGoals) {
      final progress = goal.targetAmount > 0 ? '${(goal.currentAmount / goal.targetAmount * 100).toStringAsFixed(1)}%' : '0.0%';
      final targetAmount = SettingsService.instance.formatCurrency(goal.targetAmount);
      final currentAmount = SettingsService.instance.formatCurrency(goal.currentAmount);
      
      goalData.add([
        goal.name,
        targetAmount,
        currentAmount,
        progress,
      ]);
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FoxFunds - All Data',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Transaction History',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                data: transactionData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellHeight: 20,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                },
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Goals',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                data: goalData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellHeight: 20,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.center,
                },
              ),
            ],
          );
        },
      ),
    );
    
    return pdf.save();
  }

  // Helper method to export based on type
  Future<String> _exportToCSV(String type) async {
    switch (type.toLowerCase()) {
      case 'transactions':
        return await exportTransactionsToCSV();
      case 'goals':
        return await exportGoalsToCSV();
      case 'categories':
        return await exportCategoriesToCSV();
      case 'budget':
        return await exportBudgetToCSV();
      case 'all':
        return await exportAllDataToCSV();
      default:
        throw Exception('Unknown export type: $type');
    }
  }

  // Helper method to export to PDF based on type
  Future<Uint8List> _exportToPDF(String type) async {
    switch (type.toLowerCase()) {
      case 'transactions':
        return await exportTransactionsToPDF();
      case 'goals':
        return await exportGoalsToPDF();
      case 'categories':
        return await exportCategoriesToPDF();
      case 'budget':
        return await exportBudgetToPDF();
      case 'all':
        return await exportAllDataToPDF();
      default:
        throw Exception('Unknown export type: $type');
    }
  }

  // Import data from CSV
  Future<Map<String, dynamic>> importFromCSV(String csvContent) async {
    try {
      print('DEBUG: Starting CSV import...');
      print('DEBUG: CSV content length: ${csvContent.length}');
      print('DEBUG: First 200 characters: ${csvContent.substring(0, csvContent.length > 200 ? 200 : csvContent.length)}');
      
      final lines = csvContent.split('\n');
      print('DEBUG: Total lines: ${lines.length}');
      
      if (lines.isEmpty) {
        return {
          'success': false,
          'message': 'Empty CSV file',
        };
      }

      int importedCount = 0;
      int skippedCount = 0;
      int categoryCount = 0;
      int budgetCount = 0;

      // Split content into sections
      final sections = <String, List<String>>{};
      String currentSection = '';
      List<String> currentLines = [];

      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        // Check for section headers
        if (trimmedLine.startsWith('===') && trimmedLine.endsWith('===')) {
          // Save previous section
          if (currentSection.isNotEmpty && currentLines.isNotEmpty) {
            sections[currentSection] = List.from(currentLines);
          }
          // Start new section
          currentSection = trimmedLine.replaceAll('=', '').trim().toLowerCase();
          currentLines = [];
          print('DEBUG: Found section: $currentSection');
        } else {
          currentLines.add(trimmedLine);
        }
      }
      
      // Save last section
      if (currentSection.isNotEmpty && currentLines.isNotEmpty) {
        sections[currentSection] = List.from(currentLines);
      }

      print('DEBUG: Found sections: ${sections.keys.toList()}');

      // Process each section
      for (final entry in sections.entries) {
        final sectionName = entry.key;
        final sectionLines = entry.value;
        
        print('DEBUG: Processing section: $sectionName with ${sectionLines.length} lines');

        if (sectionName == 'transactions') {
          // Import transactions
          if (sectionLines.isNotEmpty) {
            final header = sectionLines[0].toLowerCase();
            if (header.contains('type') && header.contains('amount')) {
              for (int i = 1; i < sectionLines.length; i++) {
                try {
                  final values = _parseCSVLine(sectionLines[i]);
                  if (values.length >= 5) {
                    // final type = values[0].toLowerCase(); // not used
                    final amountStr = values[1].replaceAll(RegExp(r'[^\d.-]'), '');
                    final categoryName = values[2].replaceAll('"', '');
                    final description = values[3].replaceAll('"', '');
                    final date = values[4];

                    // Find category
                    final existingCategories = await DatabaseService.instance.getAllCategories();
                    final category = existingCategories.firstWhere(
                      (cat) => cat.name.toLowerCase() == categoryName.toLowerCase(),
                      orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
                    );

                    final amount = double.parse(amountStr);

                    final transaction = Transaction(
                      id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
                      amount: amount,
                      date: DateTime.parse(date),
                      categoryId: category.id,
                      description: description.isEmpty ? null : description,
                    );

                    await DatabaseService.instance.createTransaction(transaction);
                    importedCount++;
                  }
                } catch (e) {
                  skippedCount++;
                }
              }
            }
          }
        } else if (sectionName == 'goals') {
          // Import goals
          if (sectionLines.isNotEmpty) {
            final header = sectionLines[0].toLowerCase();
            if (header.contains('name') && header.contains('target amount')) {
              for (int i = 1; i < sectionLines.length; i++) {
                try {
                  final values = _parseCSVLine(sectionLines[i]);
                  if (values.length >= 3) {
                    final name = values[0].replaceAll('"', '');
                    final targetAmountStr = values[1].replaceAll(RegExp(r'[^\d.-]'), '');
                    final currentAmountStr = values[2].replaceAll(RegExp(r'[^\d.-]'), '');

                    final targetAmount = double.parse(targetAmountStr);
                    final currentAmount = double.parse(currentAmountStr);

                    // Create goal
                    final goal = Goal(
                      id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
                      name: name,
                      targetAmount: targetAmount,
                      currentAmount: currentAmount,
                    );

                    await DatabaseService.instance.createGoal(goal);
                    importedCount++;
                    print('DEBUG: Imported goal: ${goal.name}');
                  }
                } catch (e) {
                  print('DEBUG: Failed to import goal: $e');
                  skippedCount++;
                }
              }
            }
          }
        } else if (sectionName == 'categories') {
          // Import categories
          if (sectionLines.isNotEmpty) {
            final header = sectionLines[0].toLowerCase();
            if (header.contains('name') && header.contains('type')) {
              for (int i = 1; i < sectionLines.length; i++) {
                try {
                  final values = _parseCSVLine(sectionLines[i]);
                  if (values.length >= 2) {
                    final name = values[0].replaceAll('"', '');
                    final type = values[1].toLowerCase();
                    final categoryType = type == 'income' ? CategoryType.income : CategoryType.expense;

                    // Check if category already exists
                    final existingCategories = await DatabaseService.instance.getAllCategories();
                    final exists = existingCategories.any((cat) => cat.name.toLowerCase() == name.toLowerCase());
                    
                    if (!exists) {
                      // Create category
                      final category = Category(
                        id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
                        name: name,
                        type: categoryType,
                      );

                      await DatabaseService.instance.createCategory(category);
                      categoryCount++;
                      print('DEBUG: Imported category: ${category.name}');
                    }
                  }
                } catch (e) {
                  print('DEBUG: Failed to import category: $e');
                  skippedCount++;
                }
              }
            }
          }
        } else if (sectionName == 'budget') {
          // Import budget
          if (sectionLines.isNotEmpty) {
            final header = sectionLines[0].toLowerCase();
            if (header.contains('amount') && header.contains('duration')) {
              for (int i = 1; i < sectionLines.length; i++) {
                try {
                  final values = _parseCSVLine(sectionLines[i]);
                  if (values.length >= 5) {
                    final amountStr = values[0].replaceAll(RegExp(r'[^\d.-]'), '');
                    final duration = values[1];
                    final categoryName = values[2].replaceAll('"', '');
                    final startDate = values[3];
                    final endDate = values[4];

                    final amount = double.parse(amountStr);
                    
                    // Find category if specified
                    String? categoryId;
                    if (categoryName.toLowerCase() != 'all categories') {
                      final existingCategories = await DatabaseService.instance.getAllCategories();
                      final category = existingCategories.firstWhere(
                        (cat) => cat.name.toLowerCase() == categoryName.toLowerCase(),
                        orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
                      );
                      categoryId = category.id;
                    }

                    // Create budget
                    final budget = Budget(
                      id: 'user_main_budget',
                      amount: amount,
                      duration: duration,
                      startDate: DateTime.parse(startDate),
                      endDate: DateTime.parse(endDate),
                      categoryId: categoryId,
                    );

                    await DatabaseService.instance.createOrUpdateBudget(budget);
                    budgetCount++;
                    print('DEBUG: Imported budget: ${budget.amount}');
                  }
                } catch (e) {
                  print('DEBUG: Failed to import budget: $e');
                  skippedCount++;
                }
              }
            }
          }
        }
      }

      String message = 'Imported $importedCount items successfully';
      if (categoryCount > 0) message += ', $categoryCount categories';
      if (budgetCount > 0) message += ', $budgetCount budget';
      if (skippedCount > 0) message += ', skipped $skippedCount invalid rows';

      print('DEBUG: Import completed - $importedCount items, $categoryCount categories, $budgetCount budgets, $skippedCount skipped');

      // If no sections were found, try simple CSV import
      if (sections.isEmpty && lines.length > 1) {
        print('DEBUG: No sections found, trying simple CSV import...');
        return await _importSimpleCSV(lines);
      }

      return {
        'success': true,
        'message': message,
        'importedCount': importedCount,
        'skippedCount': skippedCount,
      };
    } catch (e) {
      print('DEBUG: Import failed with error: $e');
      return {
        'success': false,
        'message': 'Import failed: $e',
      };
    }
  }

  // Fallback method for simple CSV files without sections
  Future<Map<String, dynamic>> _importSimpleCSV(List<String> lines) async {
    try {
      print('DEBUG: Starting simple CSV import...');
      int importedCount = 0;
      int skippedCount = 0;

      if (lines.length < 2) {
        return {
          'success': false,
          'message': 'CSV file must have at least a header and one data row',
        };
      }

      final header = lines[0].toLowerCase();
      print('DEBUG: CSV header: $header');

      // Try to determine the type based on header
      if (header.contains('type') && header.contains('amount') && header.contains('category')) {
        print('DEBUG: Detected transactions CSV');
        // Import transactions
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          try {
            final values = _parseCSVLine(line);
            print('DEBUG: Parsed values: $values');
            
            if (values.length >= 5) {
              final type = values[0].toLowerCase();
              final amountStr = values[1].replaceAll(RegExp(r'[^\d.-]'), '');
              final categoryName = values[2].replaceAll('"', '');
              final description = values[3].replaceAll('"', '');
              final date = values[4];

              print('DEBUG: Processing transaction - Type: $type, Amount: $amountStr, Category: $categoryName');

              // Find or create category
              final existingCategories = await DatabaseService.instance.getAllCategories();
              Category category = existingCategories.firstWhere(
                (cat) => cat.name.toLowerCase() == categoryName.toLowerCase(),
                orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
              );

              final amount = double.parse(amountStr);

              // Create transaction
              final transaction = Transaction(
                id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
                amount: amount,
                date: DateTime.parse(date),
                categoryId: category.id,
                description: description.isEmpty ? null : description,
              );

              await DatabaseService.instance.createTransaction(transaction);
              importedCount++;
              print('DEBUG: Successfully imported transaction: ${transaction.amount}');
            }
          } catch (e) {
            print('DEBUG: Failed to import transaction row $i: $e');
            skippedCount++;
          }
        }
      } else if (header.contains('name') && header.contains('target amount')) {
        print('DEBUG: Detected goals CSV');
        // Import goals
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          try {
            final values = _parseCSVLine(line);
            if (values.length >= 3) {
              final name = values[0].replaceAll('"', '');
              final targetAmountStr = values[1].replaceAll(RegExp(r'[^\d.-]'), '');
              final currentAmountStr = values[2].replaceAll(RegExp(r'[^\d.-]'), '');

              final targetAmount = double.parse(targetAmountStr);
              final currentAmount = double.parse(currentAmountStr);

              // Create goal
              final goal = Goal(
                id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
                name: name,
                targetAmount: targetAmount,
                currentAmount: currentAmount,
              );

              await DatabaseService.instance.createGoal(goal);
              importedCount++;
              print('DEBUG: Successfully imported goal: ${goal.name}');
            }
          } catch (e) {
            print('DEBUG: Failed to import goal row $i: $e');
            skippedCount++;
          }
        }
      } else {
        return {
          'success': false,
          'message': 'Unsupported CSV format. Please use the export function to create compatible CSV files.',
        };
      }

      return {
        'success': true,
        'message': 'Imported $importedCount items successfully${skippedCount > 0 ? ', skipped $skippedCount invalid rows' : ''}',
        'importedCount': importedCount,
        'skippedCount': skippedCount,
      };
    } catch (e) {
      print('DEBUG: Simple CSV import failed: $e');
      return {
        'success': false,
        'message': 'Import failed: $e',
      };
    }
  }

  // Helper method to parse CSV line
  List<String> _parseCSVLine(String line) {
    final result = <String>[];
    String current = '';
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    
    result.add(current.trim());
    return result;
  }

  // Get export statistics
  Future<Map<String, dynamic>> getExportStats() async {
    final transactions = await DatabaseService.instance.getAllTransactions();
    final goals = await DatabaseService.instance.getAllGoals();
    
    double totalIncome = 0;
    double totalExpense = 0;
    
    for (final transaction in transactions) {
      final category = predefinedCategories.firstWhere(
        (cat) => cat.id == transaction.categoryId,
        orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
      );
      if (category.type == CategoryType.income) {
        totalIncome += transaction.amount;
      } else {
        totalExpense += transaction.amount;
      }
    }
    
    return {
      'totalTransactions': transactions.length,
      'totalGoals': goals.length,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }

  // ===== Backup (.ffx) support =====
  static const String _internalAutoBackupName = 'foxfunds_autobackup.ffx';

  Future<File> _writeInternalAutoBackup(List<int> bytes) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDir.path, _internalAutoBackupName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File?> _getInternalAutoBackupFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final f = File(p.join(appDir.path, _internalAutoBackupName));
    return await f.exists() ? f : null;
  }

  Future<Uint8List?> getInternalAutoBackupBytes() async {
    final f = await _getInternalAutoBackupFile();
    if (f == null) return null;
    return await f.readAsBytes();
  }

  Future<Map<String, dynamic>> createBackupJson() async {
    final transactions = await DatabaseService.instance.getAllTransactions();
    final goals = await DatabaseService.instance.getAllGoals();
    final categories = await DatabaseService.instance.getAllCategories();
    final budget = await DatabaseService.instance.getActiveBudget();
    final recurring = await DatabaseService.instance.getAllRecurringTransactions();
    final settings = {
      'currency': SettingsService.instance.currency,
      'currencyFormat': SettingsService.instance.currencyFormat,
      'isDarkMode': SettingsService.instance.isDarkMode,
      'language': SettingsService.instance.language,
      'accentColor': SettingsService.instance.accentColor.value,
      'notificationsEnabled': SettingsService.instance.notificationsEnabled,
    };
    return {
      'meta': {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
      },
      'data': {
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'goals': goals.map((g) => g.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'budget': budget?.toMap(),
        'recurring': recurring.map((r) => r.toMap()).toList(),
        'settings': settings,
      },
    };
  }

  Future<Map<String, dynamic>> exportBackup() async {
    try {
      final jsonMap = await createBackupJson();
      final jsonStr = jsonEncode(jsonMap);
      final raw = utf8.encode(jsonStr);
      final gzipped = GZipEncoder().encode(raw) ?? raw;
      final filename = 'foxfunds_${_formatDateTime(DateTime.now())}.ffx';

      // Save in app dir and public backup folder
      final savedPaths = await _saveFileInMultipleLocations(filename, gzipped, true);
      // Save/overwrite internal autobackup
      await _writeInternalAutoBackup(gzipped);

      return {
        'success': true,
        'message': 'Backup created',
        'filename': filename,
        'filePath': savedPaths.isNotEmpty ? savedPaths.first : null,
        'publicCopyPath': savedPaths.length > 1 ? savedPaths[1] : null,
        'internalPath': (await _getInternalAutoBackupFile())?.path,
        'originalSize': raw.length,
        'compressedSize': gzipped.length,
      };
    } catch (e) {
      return {'success': false, 'message': 'Backup failed: $e'};
    }
  }

  Future<Map<String, dynamic>> importBackupBytes(Uint8List bytes) async {
    try {
      final decoded = GZipDecoder().decodeBytes(bytes);
      final jsonStr = utf8.decode(decoded);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final data = map['data'] as Map<String, dynamic>;

      // Clean slate to avoid PRIMARY KEY conflicts
      await DatabaseService.instance.forceRecreateDatabase();

      // Categories
      final catList = (data['categories'] as List).cast<Map<String, dynamic>>();
      for (final c in catList) {
        await DatabaseService.instance.createCategory(Category.fromMap(c));
      }

      // Goals
      final goalList = (data['goals'] as List).cast<Map<String, dynamic>>();
      for (final g in goalList) {
        await DatabaseService.instance.createGoal(Goal.fromMap(g));
      }

      // Transactions
      final txList = (data['transactions'] as List).cast<Map<String, dynamic>>();
      for (final t in txList) {
        await DatabaseService.instance.createTransaction(Transaction.fromMap(t));
      }

      // Recurring
      final recList = (data['recurring'] as List).cast<Map<String, dynamic>>();
      for (final r in recList) {
        await DatabaseService.instance.createOrUpdateRecurringTransaction(RecurringTransaction.fromMap(r));
      }

      // Budget
      if (data['budget'] != null) {
        await DatabaseService.instance.createOrUpdateBudget(Budget.fromMap(data['budget'] as Map<String, dynamic>));
      }

      // Settings
      final settings = data['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        await SettingsService.instance.saveSettings(
          currency: settings['currency'] as String?,
          currencyFormat: settings['currencyFormat'] as String?,
          isDarkMode: settings['isDarkMode'] as bool?,
          language: settings['language'] as String?,
          accentColor: Color(settings['accentColor'] as int),
          notificationsEnabled: settings['notificationsEnabled'] as bool?,
        );
      }

      return {'success': true, 'message': 'Backup imported successfully'};
    } catch (e) {
      return {'success': false, 'message': 'Import failed: $e'};
    }
  }

  Future<Map<String, dynamic>> exportPdfSummary() async {
    try {
      final stats = await getExportStats();
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('FoxFunds Summary', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Text('Exported: ${DateTime.now().toIso8601String()}'),
              pw.SizedBox(height: 24),
              pw.Table.fromTextArray(
                data: [
                  ['Metric', 'Value'],
                  ['Transactions', stats['totalTransactions'].toString()],
                  ['Goals', stats['totalGoals'].toString()],
                  ['Total Income', SettingsService.instance.formatCurrency(stats['totalIncome'])],
                  ['Total Expense', SettingsService.instance.formatCurrency(stats['totalExpense'])],
                  ['Balance', SettingsService.instance.formatCurrency(stats['balance'])],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 12),
                cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
              ),
            ],
          ),
        ),
      );
      final bytes = await pdf.save();
      final filename = 'foxfunds_summary_${_formatDateTime(DateTime.now())}.pdf';
      final saved = await _saveFileInMultipleLocations(filename, bytes, true);
      if (saved.isNotEmpty) {
        await OpenFile.open(saved.first);
      }
      return {'success': true, 'message': 'Summary PDF exported', 'filename': filename, 'filePath': saved.first};
    } catch (e) {
      return {'success': false, 'message': 'PDF export failed: $e'};
    }
  }
}