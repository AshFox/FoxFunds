import 'package:flutter/material.dart';
import 'package:foxfunds/models/budget.dart';
import 'package:foxfunds/models/category.dart';
import 'package:foxfunds/services/database_service.dart';

class SetBudgetDialog extends StatefulWidget {
  final Budget? activeBudget;

  const SetBudgetDialog({super.key, this.activeBudget});

  @override
  _SetBudgetDialogState createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends State<SetBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late String _duration;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: widget.activeBudget?.amount.round().toString() ?? '');
    _duration = widget.activeBudget?.duration ?? 'weekly';
    _selectedCategoryId = widget.activeBudget?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text);
      if (amount == null) return;

      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      if (_duration == 'weekly') {
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(
            startDate.year, startDate.month, startDate.day + 6, 23, 59, 59);
      } else { // monthly
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month + 1, now.day, 23, 59, 59);
      }

      final budget = Budget(
        id: 'user_main_budget', // Use a fixed ID
        amount: amount,
        startDate: startDate,
        endDate: endDate,
        duration: _duration,
        categoryId: _selectedCategoryId,
      );

      await DatabaseService.instance.createOrUpdateBudget(budget);
      
      if (mounted) {
        Navigator.pop(context, true); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = predefinedCategories
        .where((cat) => cat.type == CategoryType.expense)
        .toList();

    return AlertDialog(
      title: const Text('Set Budget'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              hint: const Text('For All Expenses (Optional)'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Expenses'),
                ),
                ...expenseCategories.map((Category category) {
                  return DropdownMenuItem<String>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategoryId = newValue;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Budget Amount',
                prefixText: 'LYD '
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a positive number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
                ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ],
              selected: {_duration},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _duration = newSelection.first;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.activeBudget != null)
              TextButton(
                onPressed: () async {
                  await DatabaseService.instance.deleteBudget('user_main_budget');
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
} 