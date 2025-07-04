import 'package:flutter/material.dart';
import 'package:foxfunds/models/category.dart';
import 'package:foxfunds/models/transaction.dart' as model;
import 'package:foxfunds/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// A screen for adding a new transaction or editing an existing one.
class AddTransactionScreen extends StatefulWidget {
  /// The transaction to be edited. If null, a new transaction will be created.
  final model.Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isIncome = false; // Default to Expense

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  /// Sets up the form fields based on whether we are editing or creating.
  void _initializeFields() {
    if (_isEditing) {
      final transaction = widget.transaction!;
      _amountController =
          TextEditingController(text: transaction.amount.toString());
      _descriptionController =
          TextEditingController(text: transaction.description ?? '');
      _selectedCategoryId = transaction.categoryId;
      _selectedDate = transaction.date;

      // Determine if the transaction is income or expense from its category
      final category = predefinedCategories.firstWhere(
        (cat) => cat.id == _selectedCategoryId,
        orElse: () => predefinedCategories.first, // Fallback
      );
      _isIncome = category.type == CategoryType.income;
    } else {
      // For creating a new transaction, start with empty fields
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

  /// Validates the form and saves the transaction to the database.
  void _submitForm() async {
    // Hide the keyboard
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || _selectedCategoryId == null) {
        // This should not happen if validator is correct, but as a safeguard:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields.')),
        );
        return;
      }

      final transaction = model.Transaction(
        id: _isEditing ? widget.transaction!.id : const Uuid().v4(),
        amount: amount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        description: _descriptionController.text.trim(),
      );

      try {
        if (_isEditing) {
          await DatabaseService.instance.updateTransaction(transaction);
        } else {
          await DatabaseService.instance.createTransaction(transaction);
        }
        // Pop the screen and signal that data has changed
        Navigator.of(context).pop(true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save transaction: $e')),
          );
        }
      }
    }
  }

  /// Shows the date picker dialog.
  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
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
              _buildDateField(),
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
      decoration: const InputDecoration(
        labelText: 'Amount',
        prefixIcon: Icon(Icons.attach_money),
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
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('Income')),
          ButtonSegment(value: false, label: Text('Expense')),
        ],
        selected: {_isIncome},
        onSelectionChanged: (newSelection) {
          setState(() {
            _isIncome = newSelection.first;
            // Reset category when type changes to avoid invalid combinations
            _selectedCategoryId = null;
          });
        },
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final availableCategories = predefinedCategories
        .where((cat) =>
            cat.type == (_isIncome ? CategoryType.income : CategoryType.expense) &&
            cat.id != 'jar_contribution')
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

  Widget _buildDateField() {
    return ListTile(
      leading: const Icon(Icons.calendar_today),
      title: const Text('Date'),
      subtitle: Text(DateFormat.yMMMd().format(_selectedDate)),
      onTap: () => _selectDate(context),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description (Optional)',
        prefixIcon: Icon(Icons.description),
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: _submitForm,
      icon: const Icon(Icons.save),
      label: Text(_isEditing ? 'Save Changes' : 'Add Transaction'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
} 