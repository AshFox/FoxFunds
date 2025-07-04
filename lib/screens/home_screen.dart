import 'package:flutter/material.dart';
import 'package:foxfunds/models/budget.dart';
import 'package:foxfunds/models/category.dart';
import 'package:foxfunds/models/transaction.dart';
import 'package:foxfunds/services/database_service.dart';
import 'package:foxfunds/widgets/set_budget_dialog.dart';
import 'jars_screen.dart';
import 'summary_screen.dart';
import 'settings_screen.dart';
import 'add_transaction_screen.dart';
import 'add_jar_screen.dart';

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
  List<Transaction> _transactions = [];
  final GlobalKey<JarsScreenState> _jarsKey = GlobalKey<JarsScreenState>();
  Budget? _activeBudget;
  double _spentThisPeriod = 0;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await DatabaseService.instance.getAllTransactions();

      double income = 0;
      double expense = 0;

      for (final transaction in transactions) {
        final category = predefinedCategories.firstWhere(
          (cat) => cat.id == transaction.categoryId,
          orElse: () => const Category(
              id: 'unknown', name: 'Unknown', type: CategoryType.expense),
        );

        if (category.type == CategoryType.income) {
          income += transaction.amount;
        } else {
          expense += transaction.amount;
        }
      }

      final activeBudget = await DatabaseService.instance.getActiveBudget();
      double spentThisPeriod = 0;
      if (activeBudget != null) {
        spentThisPeriod = await DatabaseService.instance.getExpensesInDateRange(
            activeBudget.startDate, activeBudget.endDate,
            categoryId: activeBudget.categoryId);
      }

      transactions.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _totalIncome = income;
        _totalExpense = expense;
        _balance = income - expense;
        _isLoading = false;
        _transactions = transactions;
        _activeBudget = activeBudget;
        _spentThisPeriod = spentThisPeriod;
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
    final List<Widget> widgetOptions = <Widget>[
      _buildDashboard(),
      JarsScreen(
          key: _jarsKey, balance: _balance, onDataChanged: _loadFinancialData),
      const SummaryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoxFunds'),
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
            label: 'Summary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent[200],
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
      case 1: // Jars
        return FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddJarScreen()),
            );
            _jarsKey.currentState?.refreshJars();
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                    'Income', 'LYD ${_totalIncome.round()}', Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard('Expense',
                    'LYD ${_totalExpense.round()}', Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBalanceCard(),
          const SizedBox(height: 18),
          const Text(
            'Transaction History',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _buildTransactionHistory(),
          ),
        ],
      ),
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
      child: SizedBox(
        height: 110,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: textColor, fontSize: 18),
              ),
              const Spacer(),
              Text(
                amount,
                style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    if (_transactions.isEmpty) {
      return const Center(child: Text('No transactions yet.'));
    }
    return ValueListenableBuilder(
      valueListenable: ValueNotifier(0), // Dummy notifier
      builder: (context, _, __) {
        return ListView.builder(
          itemCount: _transactions.length,
          itemBuilder: (context, index) {
            final transaction = _transactions[index];
            final category = predefinedCategories.firstWhere(
              (cat) => cat.id == transaction.categoryId,
              orElse: () => const Category(
                  id: 'unknown', name: 'Unknown', type: CategoryType.expense),
            );
            final isIncome = category.type == CategoryType.income;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : Colors.red,
                ),
                title: Text(transaction.description ?? ''),
                subtitle: Text(category.name),
                trailing: Text(
                  '${isIncome ? '+' : '-'}LYD ${transaction.amount.round()}',
                  style: TextStyle(
                      color: isIncome ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTransactionScreen(
                        transaction: transaction,
                      ),
                    ),
                  );
                  _loadFinancialData();
                },
                onLongPress: () {
                  _confirmDeleteTransaction(transaction);
                },
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Balance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey),
                  tooltip: _activeBudget == null ? 'Set Budget' : 'Edit Budget',
                  onPressed: _showBudgetDialog,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'LYD ${_balance.round()}',
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent),
            ),
            const SizedBox(height: 16),
            if (_activeBudget != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$budgetTitle ($budgetPeriod)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    remainingDays,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'LYD ${_spentThisPeriod.round()} of LYD ${_activeBudget!.amount.round()}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.8 ? Colors.red : Colors.blueAccent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
