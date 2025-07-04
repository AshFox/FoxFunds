import 'package:flutter/material.dart';
import 'package:foxfunds/models/jar.dart';
import 'package:foxfunds/models/transaction.dart' as model;
import 'package:foxfunds/services/database_service.dart';
import 'package:foxfunds/screens/add_jar_screen.dart';
import 'package:uuid/uuid.dart';

class JarsScreen extends StatefulWidget {
  final double balance;
  final VoidCallback onDataChanged;
  const JarsScreen(
      {super.key, required this.balance, required this.onDataChanged});

  @override
  JarsScreenState createState() => JarsScreenState();
}

class JarsScreenState extends State<JarsScreen> {
  late Future<List<Jar>> _jarsFuture;

  @override
  void initState() {
    super.initState();
    refreshJars();
  }

  void refreshJars() {
    setState(() {
      _jarsFuture = DatabaseService.instance.getAllJars();
    });
  }

  void _addFunds(Jar jar) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add to ${jar.name}'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
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
                      const SnackBar(
                          content: Text("Balance isn't enough")),
                    );
                    return;
                  }

                  final contribution = model.Transaction(
                    id: const Uuid().v4(),
                    amount: amount,
                    categoryId: 'jar_contribution',
                    date: DateTime.now(),
                    description: 'goal ${jar.name}',
                    jarId: jar.id,
                  );

                  await DatabaseService.instance
                      .createTransaction(contribution);

                  final updatedJar = jar.copyWith(
                    currentAmount: jar.currentAmount + amount,
                  );
                  await DatabaseService.instance.updateJar(updatedJar);
                  
                  Navigator.pop(context);
                  refreshJars();
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
        body: FutureBuilder<List<Jar>>(
          future: _jarsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No jars yet. Add one!'));
            }

            final jars = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: jars.length,
              itemBuilder: (context, index) {
                final jar = jars[index];
                final progress = jar.targetAmount > 0
                    ? (jar.currentAmount / jar.targetAmount).clamp(0.0, 1.0)
                    : 0.0;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(jar.name,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _addFunds(jar),
                                  child: const Text('Add Funds'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDelete(jar),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                            'LYD ${jar.currentAmount.round()} / LYD ${jar.targetAmount.round()}'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                        ),
                      ],
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

  void _confirmDelete(Jar jar) async {
    final refundedAmount = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Jar'),
          content: Text(
              'Are you sure you want to delete the "${jar.name}" jar? Any remaining funds will be returned to your main balance.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // First, delete all transactions associated with this jar
                await DatabaseService.instance
                    .deleteTransactionsForJar(jar.id);

                // Then, delete the jar itself
                await DatabaseService.instance.deleteJar(jar.id);
                Navigator.pop(context, jar.currentAmount);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (refundedAmount != null) {
      widget.onDataChanged();
      refreshJars();
    }
  }
}
