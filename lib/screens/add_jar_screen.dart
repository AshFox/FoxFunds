import 'package:flutter/material.dart';
import 'package:foxfunds/models/jar.dart';
import 'package:foxfunds/services/database_service.dart';
import 'package:uuid/uuid.dart';

class AddJarScreen extends StatefulWidget {
  const AddJarScreen({super.key});

  @override
  _AddJarScreenState createState() => _AddJarScreenState();
}

class _AddJarScreenState extends State<AddJarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final newJar = Jar(
        id: const Uuid().v4(),
        name: _nameController.text,
        targetAmount: double.parse(_targetAmountController.text),
      );

      await DatabaseService.instance.createJar(newJar);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a New Jar'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Jar Name'),
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
                child: const Text('Create Jar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 