import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'add_recurring_transaction_screen.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() => _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends State<RecurringTransactionsScreen> {
  List<RecurringTransaction> _recurringTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecurringTransactions();
  }

  Future<void> _loadRecurringTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await DatabaseService.instance.getAllRecurringTransactions();
      setState(() {
        _recurringTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading scheduled transactions: $e')),
        );
      }
    }
  }

  Future<void> _toggleRecurringTransaction(RecurringTransaction transaction) async {
    try {
      final updatedTransaction = transaction.copyWith(isActive: !transaction.isActive);
      await DatabaseService.instance.updateRecurringTransaction(updatedTransaction);
      await _loadRecurringTransactions();
      

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating transaction: $e')),
        );
    }
  }
  }

  Future<void> _deleteRecurringTransaction(RecurringTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Repeat Transaction'),
        content: Text(
          'Are you sure you want to delete "${transaction.description ?? 'this recurring transaction'}"? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.instance.deleteRecurringTransaction(transaction.id);
        await _loadRecurringTransactions();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Repeat transaction deleted')),
    );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting transaction: $e')),
          );
  }
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Transactions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recurringTransactions.isEmpty
              ? _buildEmptyState()
              : _buildRecurringTransactionsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddRecurringTransactionScreen(),
            ),
          );
          if (result == true) {
            _loadRecurringTransactions();
          }
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
          BottomNavigationBarItem(icon: SizedBox.shrink(), label: ''),
        ],
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.transparent,
        unselectedItemColor: Colors.transparent,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.repeat,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
                  Text(
            'No scheduled transactions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
                  ),
          const SizedBox(height: 12),
                  Text(
            'Add a repeat transaction to automate\nyour regular payments and income',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddRecurringTransactionScreen(),
                ),
              );
              if (result == true) {
                _loadRecurringTransactions();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add First Repeat Transaction'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
                  ),
                ],
              ),
            );
          }

  Widget _buildRecurringTransactionsList() {
    return RefreshIndicator(
      onRefresh: _loadRecurringTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recurringTransactions.length,
            itemBuilder: (context, index) {
          final transaction = _recurringTransactions[index];
          return _buildRecurringTransactionCard(transaction);
        },
      ),
    );
  }

  Widget _buildRecurringTransactionCard(RecurringTransaction transaction) {
    final category = predefinedCategories.firstWhere(
      (cat) => cat.id == transaction.categoryId,
      orElse: () => predefinedCategories.first,
    );

    final nextDueDate = transaction.getNextDueDate();
    final isDue = transaction.isDue();
    final isOverdue = nextDueDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: transaction.isActive ? 2 : 1,
      color: transaction.isActive ? null : Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (transaction.description == null || transaction.description!.trim().isEmpty)
                            ? category.name
                            : transaction.description!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: transaction.isActive ? null : Colors.grey[600],
                          ),
                        ),
                      ),

                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${category.name} • ${_getFrequencyText(transaction.frequency)}',
                    style: TextStyle(
                      color: transaction.isActive ? Colors.grey[600] : Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: isOverdue ? Colors.red : (transaction.isActive ? Colors.grey[600] : Colors.grey[400]),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Next: ${DateFormat.yMMMd().format(nextDueDate)}',
                        style: TextStyle(
                            color: isOverdue ? Colors.red : (transaction.isActive ? Colors.grey[600] : Colors.grey[400]),
                            fontSize: 12,
                            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isDue) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DUE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Trailing content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'LYD ${transaction.amount.round()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: transaction.isActive ? _getCategoryColor(category) : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        transaction.isActive ? Icons.pause : Icons.play_arrow,
                        size: 18,
                      ),
                      onPressed: () => _toggleRecurringTransaction(transaction),
                      tooltip: transaction.isActive ? 'Pause' : 'Activate',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, size: 20, color: Colors.green),
                      tooltip: 'Run now',
                      onPressed: () async {
                        try {
                          final created = await DatabaseService.instance.processRecurringTransactionNow(transaction);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Created transaction for ${DateFormat.yMMMd().format(created.date)}')),
                            );
                          }
                          await NotificationService.instance.showSimple(
                            title: 'Auto-Pay',
                            body: 'Processed: ${(transaction.description ?? '').isEmpty ? predefinedCategories.firstWhere((c)=>c.id==transaction.categoryId, orElse: ()=>predefinedCategories.first).name : transaction.description!}',
                          );
                          await _loadRecurringTransactions();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to run now: $e')),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AddRecurringTransactionScreen(
                              recurringTransaction: transaction,
                            ),
                          ),
                        );
                        if (result == true) {
                          _loadRecurringTransactions();
                        }
                      },
                      tooltip: 'Edit',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () => _deleteRecurringTransaction(transaction),
                      tooltip: 'Delete',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getFrequencyText(RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  Color _getCategoryColor(Category category) {
    // Force simple scheme: green for income, red for expense
    return category.type == CategoryType.income ? Colors.green : Colors.red;
  }
}