import 'package:flutter/material.dart';
import 'package:foxfunds/models/goal.dart';
import 'package:foxfunds/services/database_service.dart';
import 'package:uuid/uuid.dart';

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key, this.goal});

  final Goal? goal;

  @override
  _AddGoalScreenState createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.goal != null) {
      _nameController.text = widget.goal!.name;
      _targetAmountController.text = widget.goal!.targetAmount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final target = double.parse(_targetAmountController.text);

      if (widget.goal == null) {
        final newGoal = Goal(
          id: const Uuid().v4(),
          name: name,
          targetAmount: target,
        );
        await DatabaseService.instance.createGoal(newGoal);
      } else {
        final updated = widget.goal!.copyWith(
          name: name,
          targetAmount: target,
        );
        await DatabaseService.instance.updateGoal(updated);
      }
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.goal != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Goal' : 'Add a New Goal'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Goal Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _targetAmountController,
                decoration: const InputDecoration(labelText: 'Target Amount'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a target amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitForm,
                child: Text(isEditing ? 'Save Changes' : 'Create Goal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}