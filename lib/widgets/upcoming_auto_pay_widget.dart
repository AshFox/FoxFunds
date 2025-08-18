import 'package:flutter/material.dart';

import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';

class UpcomingAutoPayWidget extends StatefulWidget {
  const UpcomingAutoPayWidget({super.key});

  @override
  State<UpcomingAutoPayWidget> createState() => _UpcomingAutoPayWidgetState();
}

class _UpcomingAutoPayWidgetState extends State<UpcomingAutoPayWidget> {
  List<RecurringTransaction> _upcomingTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpcomingTransactions();
  }

  Future<void> _loadUpcomingTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allRecurring = await DatabaseService.instance.getActiveRecurringTransactions();
      final now = DateTime.now();
      final lead = SettingsService.instance.autopayReminderDays;
      
      // Filter for transactions due within the chosen lead window
      final upcoming = allRecurring.where((transaction) {
        final nextDue = transaction.getNextDueDate();
        final daysUntilDue = nextDue.difference(now).inDays;
        return daysUntilDue >= 0 && daysUntilDue <= lead;
      }).toList();
      
      // Sort by due date
      upcoming.sort((a, b) => a.getNextDueDate().compareTo(b.getNextDueDate()));
      
      // Send reminder notifications
      for (final t in upcoming) {
        final days = t.getNextDueDate().difference(now).inDays;
        // Fallback to category name when description is null/empty
        final cats = predefinedCategories;
        final catName = cats.firstWhere((c) => c.id == t.categoryId, orElse: () => cats.first).name;
        final name = (t.description == null || t.description!.trim().isEmpty) ? catName : t.description!;
        await NotificationService.instance.showAutopayReminder(name: name, daysLeft: days, id: t.id.hashCode);
      }
      
      setState(() {
        _upcomingTransactions = upcoming;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_upcomingTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Upcoming Auto-Pay',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_upcomingTransactions.length} due',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...(_upcomingTransactions.take(3).map((transaction) => 
              _buildUpcomingTransactionTile(transaction)
            )),
            if (_upcomingTransactions.length > 3) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'And ${_upcomingTransactions.length - 3} more...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingTransactionTile(RecurringTransaction transaction) {
    final category = predefinedCategories.firstWhere(
      (cat) => cat.id == transaction.categoryId,
      orElse: () => predefinedCategories.first,
    );

    final nextDueDate = transaction.getNextDueDate();
    final daysUntilDue = nextDueDate.difference(DateTime.now()).inDays;
    final isDueToday = daysUntilDue == 0;
    final isOverdue = daysUntilDue < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOverdue 
                ? Colors.red 
                : isDueToday 
                  ? Colors.orange 
                  : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (transaction.description == null || transaction.description!.trim().isEmpty)
                      ? category.name
                      : transaction.description!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
                             Text(
                 SettingsService.instance.formatCurrency(transaction.amount),
                 style: TextStyle(
                   fontWeight: FontWeight.bold,
                   color: _getCategoryColor(category),
                 ),
               ),
              Text(
                isOverdue 
                  ? 'Overdue' 
                  : isDueToday 
                    ? 'Due today' 
                    : daysUntilDue == 1 
                      ? 'Due tomorrow' 
                      : 'Due in $daysUntilDue days',
                style: TextStyle(
                  fontSize: 12,
                  color: isOverdue 
                    ? Colors.red 
                    : isDueToday 
                      ? Colors.orange 
                      : Colors.grey[600],
                  fontWeight: isOverdue || isDueToday ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(Category category) {
    // Force simple scheme: green for income, red for expense
    return category.type == CategoryType.income ? Colors.green : Colors.red;
  }
}