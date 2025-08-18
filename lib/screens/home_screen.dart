import 'package:flutter/material.dart';
import 'package:foxfunds/models/budget.dart';
import 'package:foxfunds/models/category.dart';
import 'package:foxfunds/models/transaction.dart';
import 'package:foxfunds/services/database_service.dart';
import 'package:foxfunds/widgets/set_budget_dialog.dart';
import 'package:foxfunds/widgets/upcoming_auto_pay_widget.dart';
import 'goals_screen.dart';
import 'summary_screen.dart';
import 'settings_screen.dart';
import 'add_transaction_screen.dart';
import 'add_goal_screen.dart';
import 'recurring_transactions_screen.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../models/recurring_transaction.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;
  double _monthIncome = 0;
  double _monthExpense = 0;
  List<Transaction> _transactions = [];
  final GlobalKey<GoalsScreenState> _goalsKey = GlobalKey<GoalsScreenState>();
  Budget? _activeBudget;
  double _spentThisPeriod = 0;
  List<RecurringTransaction> _recurringTemplates = [];

  // Filter state
  bool? _filterIsIncome; // null = all, true = income, false = expense
  String? _filterCategoryId;
  DateTimeRange? _filterDateRange;
  bool _filterAutoPayOnly = false;

  bool get _hasActiveFilter =>
      _filterIsIncome != null ||
      _filterCategoryId != null ||
      _filterDateRange != null ||
      _filterAutoPayOnly;

  @override
  void initState() {
    super.initState();
    // Refresh on settings change (non-theme)
    SettingsService.instance.setSettingsChangeCallback(() {
      if (mounted) {
        _loadFinancialData();
        setState(() {});
      }
    });
    // Refresh on global data change
    SettingsService.instance.setDataChangeCallback(() {
      if (mounted) {
        _loadFinancialData();
      }
    });
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final createdTransactions = await DatabaseService.instance.processDueRecurringTransactions();
      if (createdTransactions.isNotEmpty && mounted) {
        // Notification for autopay
        await NotificationService.instance.showAutopayProcessed(createdTransactions.length);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${createdTransactions.length} recurring transaction(s) processed'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final transactions = await DatabaseService.instance.getAllTransactions();
      final dbCategories = await DatabaseService.instance.getAllCategories();
      final allCats = dbCategories.isEmpty ? predefinedCategories : dbCategories;
      final recTemplates = await DatabaseService.instance.getAllRecurringTransactions();

      // Compute overall and period-based income/expense
      double income = 0, expense = 0;
      double periodIncome = 0, periodExpense = 0;
      final now = DateTime.now();
      DateTime startPeriod;
      DateTime endPeriod = DateTime(now.year, now.month, now.day, 23, 59, 59);
      switch (SettingsService.instance.homePeriod) {
        case '3m':
          startPeriod = DateTime(now.year, now.month - 2, 1);
          break;
        case '6m':
          startPeriod = DateTime(now.year, now.month - 5, 1);
          break;
        case 'year':
          startPeriod = DateTime(now.year, 1, 1);
          break;
        case 'month':
        default:
          startPeriod = DateTime(now.year, now.month, 1);
      }

      for (final t in transactions) {
        final cat = allCats.firstWhere(
          (c) => c.id == t.categoryId,
          orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
        );
        final inPeriod = !t.date.isBefore(startPeriod) && !t.date.isAfter(endPeriod);
        if (cat.type == CategoryType.income) {
          income += t.amount;
          if (inPeriod) periodIncome += t.amount;
        } else {
          expense += t.amount;
          if (inPeriod) periodExpense += t.amount;
        }
      }

      final activeBudget = await DatabaseService.instance.getActiveBudget();
      double spentThisPeriod = 0;
      if (activeBudget != null) {
        spentThisPeriod = await DatabaseService.instance.getExpensesInDateRange(
          activeBudget.startDate, activeBudget.endDate, categoryId: activeBudget.categoryId,
        );
      }

      transactions.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _totalIncome = income;
        _totalExpense = expense;
        _monthIncome = periodIncome;
        _monthExpense = periodExpense;
        _balance = income - expense;
        _isLoading = false;
        _transactions = transactions;
        _activeBudget = activeBudget;
        _spentThisPeriod = spentThisPeriod;
        _recurringTemplates = recTemplates;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading data: $e')),
          );
        });
      }
    }
  }

  bool _matchesRecurringTemplate(Transaction t) {
    final desc = (t.description ?? '').trim();
    final cleaned = desc.replaceFirst(RegExp(r'^\[AutoPay\]\s+', caseSensitive: false), '').trim();
    for (final r in _recurringTemplates) {
      if (r.categoryId == t.categoryId) {
        final sameAmount = (r.amount - t.amount).abs() < 0.01;
        final rDesc = (r.description ?? '').trim();
        final sameDesc = cleaned.isEmpty ? rDesc.isEmpty : rDesc.toLowerCase() == cleaned.toLowerCase();
        if (sameAmount && sameDesc) return true;
      }
    }
    return false;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showBudgetDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SetBudgetDialog(activeBudget: _activeBudget),
    );

    if (result == true) {
      _loadFinancialData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final iconColor = isDark ? Colors.white : Colors.white; // AppBar uses white foreground
    final List<Widget> widgetOptions = <Widget>[
      _buildDashboard(),
      GoalsScreen(
          key: _goalsKey, balance: _balance, onDataChanged: _loadFinancialData),
      const SummaryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoxFunds'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: iconColor),
            tooltip: 'Refresh',
            onPressed: _loadFinancialData,
          ),
        ],
      ),
      body: Center(
        child: widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'DashBoard'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.savings),
            label: 'Goals'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_selectedIndex) {
      case 0: // Home
        return FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AddTransactionScreen()),
            );
            _loadFinancialData();
          },
          child: const Icon(Icons.add),
        );
      case 1: // Goals
        return FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddGoalScreen()),
            );
            _goalsKey.currentState?.refreshGoals();
          },
          child: const Icon(Icons.add),
        );
      default: // Other screens
        return null;
    }
  }

  Widget _buildDashboard() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }
    final periodLabel = () {
      final hp = SettingsService.instance.homePeriod;
      if (hp == '3m') return 'Last 3 months';
      if (hp == '6m') return 'Last 6 months';
      if (hp == 'year') return 'This year';
      return 'This month';
    }();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                    'Income', SettingsService.instance.formatCurrency(_monthIncome), Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard('Expense',
                    SettingsService.instance.formatCurrency(_monthExpense), Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBalanceCard(),
          const SizedBox(height: 8), // was 18
          const UpcomingAutoPayWidget(),
          const SizedBox(height: 8), // was 18
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaction History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _showFilterSheet,
                    tooltip: 'Filter',
                    icon: Icon(
                      Icons.filter_list,
                      color: _hasActiveFilter
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showRecurringTransactions(),
                    icon: const Icon(Icons.repeat),
                    tooltip: 'Recurring Transactions',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6), // was 10
          Expanded(
            child: _buildTransactionHistory(),
          ),
        ],
      ),
    );
  }

  // Filter sheet
  Future<void> _showFilterSheet() async {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    List<Category> categories = await DatabaseService.instance.getAllCategories();
    if (categories.isEmpty) categories = predefinedCategories;

    bool? tmpIsIncome = _filterIsIncome;
    String? tmpCategoryId = _filterCategoryId;
    DateTimeRange? tmpDateRange = _filterDateRange;
    bool tmpAutoPayOnly = _filterAutoPayOnly;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final expenseCats = categories.where((c) => c.type == CategoryType.expense).toList();
        final incomeCats = categories.where((c) => c.type == CategoryType.income).toList();
        final availableCats = tmpIsIncome == null
            ? categories
            : (tmpIsIncome == true ? incomeCats : expenseCats);

        // Deduplicate by id to avoid duplicate DropdownMenuItem values
        final seenIds = <String>{};
        final uniqueCats = [for (final c in availableCats) if (seenIds.add(c.id)) c];
        // Ensure selected id exists exactly once; otherwise reset to null (All)
        if (tmpCategoryId != null && !uniqueCats.any((c) => c.id == tmpCategoryId)) {
          tmpCategoryId = null;
        }
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              // Type selector
              Center(
                child: SizedBox(
                  width: 320,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('All')),
                      ButtonSegment(value: 1, label: Text('Income')),
                      ButtonSegment(value: 2, label: Text('Expense')),
                    ],
                    selected: { tmpIsIncome == null ? 0 : (tmpIsIncome == true ? 1 : 2) },
                    onSelectionChanged: (sel) {
                      final v = sel.first;
                      setState(() {});
                      if (v == 0) tmpIsIncome = null;
                      if (v == 1) tmpIsIncome = true;
                      if (v == 2) tmpIsIncome = false;
                      // Reset category if type changes
                      tmpCategoryId = null;
                    },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(MaterialState.selected)) {
                          return primary.withOpacity(0.15);
                        }
                        return null;
                      }),
                      foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(MaterialState.selected)) {
                          return primary;
                        }
                        return null;
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Category
              DropdownButtonFormField<String>(
                value: tmpCategoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category (optional)', prefixIcon: Icon(Icons.category)),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('All Categories')),
                  ...uniqueCats.map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name)))
                ],
                onChanged: (val) {
                  tmpCategoryId = val;
                },
              ),
              const SizedBox(height: 12),
              // Date range
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range),
                title: const Text('Date range (optional)'),
                subtitle: Text(
                  tmpDateRange == null
                      ? 'Any time'
                      : '${tmpDateRange!.start.year}/${tmpDateRange!.start.month}/${tmpDateRange!.start.day} - ${tmpDateRange!.end.year}/${tmpDateRange!.end.month}/${tmpDateRange!.end.day}',
                ),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: ctx,
                    firstDate: DateTime(now.year - 5),
                    lastDate: now.add(const Duration(days: 365)),
                    initialDateRange: tmpDateRange,
                  );
                  if (picked != null) {
                    tmpDateRange = picked;
                  }
                },
                trailing: tmpDateRange != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          tmpDateRange = null;
                        },
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: tmpAutoPayOnly,
                onChanged: (v) { tmpAutoPayOnly = v; },
                title: const Text('AutoPay only'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      tmpIsIncome = null;
                      tmpCategoryId = null;
                      tmpDateRange = null;
                      tmpAutoPayOnly = false;
                    },
                    child: const Text('Reset'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterIsIncome = tmpIsIncome;
                        _filterCategoryId = tmpCategoryId;
                        _filterDateRange = tmpDateRange;
                        _filterAutoPayOnly = tmpAutoPayOnly;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
      String title, String amount, Color color, [Color? textColor]) {
    textColor ??= Colors.white;
    return Card(
      color: color,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(color: textColor, fontSize: 16),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                style: TextStyle(
                    color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    if (_transactions.isEmpty) {
      return const Center(child: Text('No transactions yet.'));
    }
    return FutureBuilder<List<Category>>(
      future: DatabaseService.instance.getAllCategories(),
      builder: (context, snapshot) {
        final dbCategories = snapshot.data ?? [];
        final allCats = dbCategories.isEmpty ? predefinedCategories : dbCategories;

        // Apply filters
        List<Transaction> list = _transactions;
        if (_filterIsIncome != null) {
          list = list.where((t) {
            final cat = allCats.firstWhere(
              (c) => c.id == t.categoryId,
              orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
            );
            return (cat.type == CategoryType.income) == _filterIsIncome;
          }).toList();
        }
        if (_filterCategoryId != null) {
          list = list.where((t) => t.categoryId == _filterCategoryId).toList();
        }
        if (_filterDateRange != null) {
          final start = DateTime(_filterDateRange!.start.year, _filterDateRange!.start.month, _filterDateRange!.start.day);
          final end = DateTime(_filterDateRange!.end.year, _filterDateRange!.end.month, _filterDateRange!.end.day, 23, 59, 59);
          list = list.where((t) => !t.date.isBefore(start) && !t.date.isAfter(end)).toList();
        }
        if (_filterAutoPayOnly) {
          list = list.where((t) {
            final desc = (t.description ?? '').trim();
            final lower = desc.toLowerCase();
            final hasTag = lower.contains('[autopay]');
            return hasTag || _matchesRecurringTemplate(t);
          }).toList();
        }

        if (list.isEmpty) {
          return const Center(child: Text('No transactions match the filter.'));
        }

        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final transaction = list[index];
            final category = allCats.firstWhere(
              (cat) => cat.id == transaction.categoryId,
              orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
            );
            final isIncome = category.type == CategoryType.income;

            final desc = (transaction.description ?? '').trim();
            final lower = desc.toLowerCase();
            final hasAutoPayTag = lower.contains('[autopay]') || _matchesRecurringTemplate(transaction);
            final accent = Theme.of(context).colorScheme.primary;
            final cleanedDesc = desc.replaceFirst(RegExp(r'^\[AutoPay\]\s+', caseSensitive: false), '').trim();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 2),
              elevation: 0,
              child: SizedBox(
                height: 52,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  horizontalTitleGap: 8,
                  minLeadingWidth: 28,
                  leading: SizedBox(
                    width: 28,
                    height: 28,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const SizedBox.expand(),
                        Align(
                          alignment: Alignment.center,
                          child: Icon(
                            isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isIncome ? Colors.green : Colors.red,
                            size: 24,
                          ),
                        ),
                        if (hasAutoPayTag)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Icon(Icons.autorenew, size: 12, color: accent),
                          ),
                      ],
                    ),
                  ),
                  title: cleanedDesc.isNotEmpty
                      ? Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: category.name),
                              TextSpan(
                                text: ' • ',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              TextSpan(
                                text: cleanedDesc,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (hasAutoPayTag) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accent, width: 1),
                          ),
                          child: Text('AutoPay', style: TextStyle(fontSize: 12, color: accent)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${isIncome ? '+' : '-'}${SettingsService.instance.formatCurrency(transaction.amount)}',
                        style: TextStyle(
                          color: isIncome ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddTransactionScreen(transaction: transaction)),
                    );
                    _loadFinancialData();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTransaction(Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text('Are you sure you want to delete this transaction?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await DatabaseService.instance.deleteTransaction(transaction.id);
                Navigator.pop(context); // Close the dialog
                _loadFinancialData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Transaction deleted successfully')),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBalanceCard() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    double progress = 0;
    if (_activeBudget != null && _activeBudget!.amount > 0) {
      progress = (_spentThisPeriod / _activeBudget!.amount).clamp(0, 1);
    }
    String budgetPeriod =
        _activeBudget?.duration == 'weekly' ? 'this week' : 'this month';
    String remainingDays = '';
    if (_activeBudget != null) {
      final days = _activeBudget!.endDate.difference(DateTime.now()).inDays;
      if (days >= 0) {
        remainingDays = '$days days left';
      }
    }
    // Short labels for compact display
    final String periodShort = _activeBudget?.duration == 'weekly' ? 'wk' : 'mo';
    final String daysLeftShort = (() {
      if (_activeBudget == null) return '';
      final d = _activeBudget!.endDate.difference(DateTime.now()).inDays;
      return d >= 0 ? '${d}d left' : '';
    })();

    String budgetTitle = 'Budget';
    if (_activeBudget?.categoryId != null) {
      try {
        final category = predefinedCategories
            .firstWhere((cat) => cat.id == _activeBudget!.categoryId);
        budgetTitle = 'Budget for ${category.name}';
      } catch (e) {
        // Category not found, stick to default title
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0), // Decreased vertical padding further
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6), // lower the 'Balance' title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center, // center align with 'Balance'
              children: [
                const Text(
                  'Balance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, height: 1.0),
                ),
                Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                    tooltip: _activeBudget == null ? 'Set Budget' : 'Edit Budget',
                    onPressed: _showBudgetDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 0), // minimized spacing between title and amount
            Text(
              SettingsService.instance.formatCurrency(_balance),
              style: TextStyle(
                  fontSize: 28, // Smaller font
                  fontWeight: FontWeight.bold,
                  color: primary),
            ),
            const SizedBox(height: 6), // tighter spacing
            if (_activeBudget != null) ...[
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.2,
                      ) ?? const TextStyle(fontSize: 13),
                  children: [
                    // Numbers first
                    TextSpan(
                      text:
                          '${SettingsService.instance.formatCurrency(_spentThisPeriod)} / ${SettingsService.instance.formatCurrency(_activeBudget!.amount)}  •  ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    // Then the compact budget label
                    TextSpan(
                      text:
                          'Budget $periodShort${daysLeftShort.isNotEmpty ? ' - $daysLeftShort' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.8 ? Colors.red : primary,
                  ),
                ),
              ),
              const SizedBox(height: 6), // add space under progress bar
            ],
          ],
        ),
      ),
    );
  }

  void _showRecurringTransactions() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecurringTransactionsScreen(),
      ),
    );
    if (result == true) {
      _loadFinancialData();
    }
  }
}
