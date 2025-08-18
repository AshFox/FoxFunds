import 'package:flutter/material.dart';
import 'package:foxfunds/models/goal.dart';
import 'package:foxfunds/models/transaction.dart' as model;
import 'package:foxfunds/screens/add_goal_screen.dart';
import 'package:foxfunds/services/database_service.dart';
import 'package:foxfunds/services/settings_service.dart';
import 'package:uuid/uuid.dart';

class GoalsScreen extends StatefulWidget {
  final double balance;
  final VoidCallback onDataChanged;
  const GoalsScreen({super.key, required this.balance, required this.onDataChanged});

  @override
  GoalsScreenState createState() => GoalsScreenState();
}

class GoalsScreenState extends State<GoalsScreen> {
  late Future<List<Goal>> _goalsFuture;

  @override
  void initState() {
    super.initState();
    refreshGoals();
  }

  void refreshGoals() {
    DatabaseService.instance.ensureCategorySeed();
    setState(() {
      _goalsFuture = DatabaseService.instance.getAllGoals();
    });
  }

  void _addFunds(Goal goal) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add to ${goal.name}'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  if (amount > widget.balance) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Balance isn't enough")),
                    );
                    return;
                  }

                  final contribution = model.Transaction(
                    id: const Uuid().v4(),
                    amount: amount,
                    categoryId: 'goal_contribution',
                    date: DateTime.now(),
                    description: 'goal ${goal.name}',
                    goalId: goal.id,
                  );

                  await DatabaseService.instance.createTransaction(contribution);

                  final updatedGoal = goal.copyWith(
                    currentAmount: goal.currentAmount + amount,
                  );
                  await DatabaseService.instance.updateGoal(updatedGoal);
                  
                  Navigator.pop(context);
                  refreshGoals();
                  widget.onDataChanged();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, null);
        return false;
      },
      child: Scaffold(
        body: FutureBuilder<List<Goal>>(
          future: _goalsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No goals yet. Add one!'));
            }

            final goals = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final target = goal.targetAmount;
                final current = goal.currentAmount;
                final rawProgress = target > 0 ? (current / target) : 0.0;
                final progress = rawProgress.clamp(0.0, 1.0);
                final isComplete = rawProgress >= 1.0 && target > 0;
                final primary = Theme.of(context).colorScheme.primary;
                final barColor = isComplete ? Colors.green : primary;
                return GestureDetector(
                  onTap: () => _onEditGoal(goal),
                  onLongPress: () => _onDeleteGoal(goal),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(goal.name,
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _addFunds(goal),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.2),
                                    ),
                                    child: const Text('Add Funds'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${SettingsService.instance.formatCurrency(current)} / ${SettingsService.instance.formatCurrency(target)}',
                              ),
                              Text(
                                '${(rawProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                style: TextStyle(color: isComplete ? Colors.green : Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 12,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                            ),
                          ),
                          if (isComplete) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: const [
                                Icon(Icons.check_circle, color: Colors.green, size: 16),
                                SizedBox(width: 6),
                                Text('Goal reached', style: TextStyle(color: Colors.green)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _onEditGoal(Goal goal) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddGoalScreen(goal: goal)),
    );
    refreshGoals();
  }

  void _onDeleteGoal(Goal goal) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Goal'),
          content: Text('Delete "${goal.name}"? All linked contributions will be removed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                await DatabaseService.instance.deleteTransactionsForGoal(goal.id);
                await DatabaseService.instance.deleteGoal(goal.id);
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
                refreshGoals();
                widget.onDataChanged();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Goal deleted.')),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
