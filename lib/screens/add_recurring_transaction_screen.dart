import 'package:flutter/material.dart';
import 'package:foxfunds/models/category.dart';
import 'package:foxfunds/models/recurring_transaction.dart';
import 'package:foxfunds/services/database_service.dart';
import 'package:foxfunds/services/settings_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AddRecurringTransactionScreen extends StatefulWidget {
  final RecurringTransaction? recurringTransaction;

  const AddRecurringTransactionScreen({super.key, this.recurringTransaction});

  @override
  _AddRecurringTransactionScreenState createState() => _AddRecurringTransactionScreenState();
}

class _AddRecurringTransactionScreenState extends State<AddRecurringTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  String? _selectedCategoryId;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  bool _isIncome = false;
  bool _hasEndDate = false;

  bool get _isEditing => widget.recurringTransaction != null;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (_isEditing) {
      final recurring = widget.recurringTransaction!;
      _amountController = TextEditingController(text: recurring.amount.toString());
      _descriptionController = TextEditingController(text: recurring.description);
      _selectedCategoryId = recurring.categoryId;
      _startDate = recurring.startDate;
      _endDate = recurring.endDate;
      _frequency = recurring.frequency;
      _hasEndDate = recurring.endDate != null;
      
      final category = predefinedCategories.firstWhere(
        (cat) => cat.id == _selectedCategoryId,
        orElse: () => predefinedCategories.first,
      );
      _isIncome = category.type == CategoryType.income;
    } else {
      _amountController = TextEditingController();
      _descriptionController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || _selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }

      final recurringTransaction = RecurringTransaction(
        id: widget.recurringTransaction?.id ?? const Uuid().v4(),
        amount: amount,
        categoryId: _selectedCategoryId!,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        frequency: _frequency,
        startDate: _startDate,
        endDate: _hasEndDate ? _endDate : null,
        isActive: true,
        lastProcessedDate:
            _isEditing ? widget.recurringTransaction!.lastProcessedDate : null,
      );

      try {
        if (_isEditing) {
          await DatabaseService.instance
              .updateRecurringTransaction(recurringTransaction);
        } else {
          await DatabaseService.instance
              .createOrUpdateRecurringTransaction(recurringTransaction);
        }
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save recurring transaction: $e')),
          );
        }
      }
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Repeat Transaction' : 'Add Repeat Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAmountField(),
              const SizedBox(height: 24),
              _buildTypeSelector(),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),
              _buildFrequencySelector(),
              const SizedBox(height: 16),
              _buildStartDateField(),
              const SizedBox(height: 16),
              _buildEndDateToggle(),
              if (_hasEndDate) ...[
                const SizedBox(height: 16),
                _buildEndDateField(),
              ],
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: InputDecoration(
        labelText: 'Amount',
        prefixIcon: Icon(Icons.attach_money),
        prefixText: '${SettingsService.instance.currencySymbol} ',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter an amount.';
        }
        final amount = double.tryParse(value);
        if (amount == null) {
          return 'Please enter a valid number.';
        }
        if (amount <= 0) {
          return 'Amount must be positive.';
        }
        return null;
      },
    );
  }

  Widget _buildTypeSelector() {
    return Center(
      child: SizedBox(
        width: 300,
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Income')),
            ButtonSegment(value: false, label: Text('Expense')),
          ],
          selected: {_isIncome},
          onSelectionChanged: (newSelection) {
            setState(() {
              _isIncome = newSelection.first;
              _selectedCategoryId = null;
            });
          },
          showSelectedIcon: false,
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.blue.withOpacity(0.15);
              }
              return null;
            }),
            foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.blue;
              }
              return null;
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final availableCategories = predefinedCategories
        .where((cat) =>
            cat.type == (_isIncome ? CategoryType.income : CategoryType.expense) &&
            cat.id != 'goal_contribution')
        .toList();

    return DropdownButtonFormField<String>(
      value: _selectedCategoryId,
      decoration: const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(Icons.category),
      ),
      items: availableCategories.map((category) {
        return DropdownMenuItem(
          value: category.id,
          child: Text(category.name),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategoryId = value;
        });
      },
      validator: (value) =>
          value == null ? 'Please select a category.' : null,
    );
  }

  Widget _buildFrequencySelector() {
    return DropdownButtonFormField<RecurringFrequency>(
      value: _frequency,
      decoration: const InputDecoration(
        labelText: 'Frequency',
        prefixIcon: Icon(Icons.repeat),
      ),
      items: RecurringFrequency.values.map((frequency) {
        String label;
        switch (frequency) {
          case RecurringFrequency.monthly:
            label = 'Monthly';
            break;
          case RecurringFrequency.yearly:
            label = 'Yearly';
            break;
        }
        return DropdownMenuItem(
          value: frequency,
          child: Text(label),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _frequency = value;
          });
        }
      },
    );
  }

  Widget _buildStartDateField() {
    return ListTile(
      leading: const Icon(Icons.calendar_today),
      title: const Text('Start Date'),
      subtitle: Text(DateFormat.yMMMd().format(_startDate)),
      onTap: () => _selectStartDate(context),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildEndDateToggle() {
    return CheckboxListTile(
      title: const Text('Set End Date'),
      value: _hasEndDate,
      onChanged: (value) {
        setState(() {
          _hasEndDate = value ?? false;
          if (!_hasEndDate) {
            _endDate = null;
          }
        });
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildEndDateField() {
    return ListTile(
      leading: const Icon(Icons.event_busy),
      title: const Text('End Date'),
      subtitle: Text(_endDate != null 
          ? DateFormat.yMMMd().format(_endDate!)
          : 'Select end date'),
      onTap: () => _selectEndDate(context),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description (optional)',
        prefixIcon: Icon(Icons.description),
      ),
      textCapitalization: TextCapitalization.sentences,
      validator: (_) => null,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: _submitForm,
      icon: const Icon(Icons.save),
      label: Text(_isEditing ? 'Save Changes' : 'Add Repeat Transaction'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}