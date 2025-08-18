import 'package:flutter/material.dart';
import 'package:foxfunds/models/category.dart';
import 'package:foxfunds/services/database_service.dart';
import 'package:uuid/uuid.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<Category> _categories = [];
  bool _loading = true;
  int _listVersion = 0; // Add this to force list rebuild

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final cats = await DatabaseService.instance.getAllCategories();
      setState(() {
        _categories = cats;
        _loading = false;
        _listVersion++; // Increment the key
      });
      // Debug print
      print('Categories in DB: \n' + cats.map((c) => '${c.id}: ${c.name} (${c.type})').join("\n"));
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  Future<void> _showCategoryDialog({Category? category}) async {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    CategoryType type = category?.type ?? CategoryType.expense;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Category' : 'Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Category Name'),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 300,
                  child: SegmentedButton<CategoryType>(
                    segments: const [
                      ButtonSegment(value: CategoryType.income, label: Text('Income')),
                      ButtonSegment(value: CategoryType.expense, label: Text('Expense')),
                    ],
                    selected: {type},
                    onSelectionChanged: (newSelection) {
                      setDialogState(() {
                        type = newSelection.first;
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
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                if (isEdit) {
                  await DatabaseService.instance.updateCategory(
                    Category(id: category.id, name: name, type: type),
                  );
                } else {
                  await DatabaseService.instance.createCategory(
                    Category(id: const Uuid().v4(), name: name, type: type),
                  );
                }
                if (mounted) Navigator.pop(context, true);
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
    if (result == true) _loadCategories();
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.deleteCategory(category.id);
      _loadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              key: ValueKey(_listVersion), // Add this key
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _categories.length + 1,
              separatorBuilder: (_, i) => i < _categories.length - 1 ? const Divider(height: 1) : const SizedBox.shrink(),
              itemBuilder: (context, i) {
                if (i < _categories.length) {
                  final cat = _categories[i];
                  return ListTile(
                    leading: Icon(
                      cat.type == CategoryType.income ? Icons.arrow_downward : Icons.arrow_upward,
                      color: cat.type == CategoryType.income ? Colors.green : Colors.red,
                    ),
                    title: Text(cat.name),
                    subtitle: Text(cat.type == CategoryType.income ? 'Income' : 'Expense'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showCategoryDialog(category: cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteCategory(cat),
                        ),
                      ],
                    ),
                  );
                } else {
                  return const Divider(height: 1);
                }
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Add Category',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
} 