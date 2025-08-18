import 'dart:math';
import 'package:flutter/material.dart';
import 'package:foxfunds/models/category.dart';
import 'package:foxfunds/models/transaction.dart' as ff;
import 'package:foxfunds/services/database_service.dart';
import 'package:foxfunds/services/settings_service.dart';
import 'package:uuid/uuid.dart';

enum _Period { monthly, yearly }

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  _Period _period = _Period.monthly;
  bool _isSeeding = false;

  Future<(List<ff.Transaction>, List<Category>)> _load() async {
    final txns = await DatabaseService.instance.getAllTransactions();
    final cats = await DatabaseService.instance.getAllCategories();
    return (txns, cats.isEmpty ? predefinedCategories : cats);
  }

  // Create sample transactions spanning the current year
  Future<void> _generateSampleYearData() async {
    if (_isSeeding) return;
    setState(() => _isSeeding = true);
    try {
      final (_, catsRaw) = await _load();
      final cats = catsRaw;
      if (cats.isEmpty) return;

      // Helper: get category by id with fallback to any matching type
      Category? byId(String id) => cats.firstWhere((c) => c.id == id, orElse: () => const Category(id: 'none', name: 'n/a', type: CategoryType.expense));
      List<Category> incomeCats = cats.where((c) => c.type == CategoryType.income).toList();
      List<Category> expenseCats = cats.where((c) => c.type == CategoryType.expense).toList();
      if (incomeCats.isEmpty && expenseCats.isEmpty) return;

      final rand = Random();
      final uuid = const Uuid();
      final now = DateTime.now();
      final year = now.year;

      String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      int lastDay(int y, int m) => DateTime(y, m + 1, 0).day;

      for (int month = 1; month <= 12; month++) {
        final daysInMonth = lastDay(year, month);

        // Fixed pattern incomes
        final salaryCat = byId('salary');
        if (salaryCat != null && salaryCat.id != 'none') {
          final d = DateTime(year, month, 1, 9, 0);
          final amount = 2500 + rand.nextInt(1500); // 2500 - 3999
          await DatabaseService.instance.createTransaction(ff.Transaction(
            id: uuid.v4(),
            amount: amount.toDouble(),
            categoryId: salaryCat.id,
            date: d,
            description: 'Salary ${ymd(d)}',
          ));
        }

        final freelanceCat = byId('freelance');
        if (freelanceCat != null && freelanceCat.id != 'none' && rand.nextBool()) {
          final day = 10 + rand.nextInt(10); // mid-month
          final d = DateTime(year, month, day.clamp(1, daysInMonth), 17, rand.nextInt(59));
          final amount = (300 + rand.nextInt(900)).toDouble();
          await DatabaseService.instance.createTransaction(ff.Transaction(
            id: uuid.v4(),
            amount: amount,
            categoryId: freelanceCat.id,
            date: d,
            description: 'Freelance ${ymd(d)}',
          ));
        }

        // Fixed pattern expenses
        Future<void> addIfExists(String catId, double amt, int day, String label) async {
          final c = byId(catId);
          if (c != null && c.id != 'none') {
            final d = DateTime(year, month, day.clamp(1, daysInMonth), 12, rand.nextInt(59));
            await DatabaseService.instance.createTransaction(ff.Transaction(
              id: uuid.v4(),
              amount: amt,
              categoryId: c.id,
              date: d,
              description: '$label ${ymd(d)}',
            ));
          }
        }

        await addIfExists('rent', 800 + rand.nextInt(400).toDouble(), 1, 'Rent');
        await addIfExists('utilities', 60 + rand.nextInt(90).toDouble(), 10, 'Utilities');
        await addIfExists('subscriptions', 10 + rand.nextInt(25).toDouble(), 15, 'Subscriptions');

        // Groceries: 3-6 times per month
        final groceries = byId('groceries');
        if (groceries != null && groceries.id != 'none') {
          final count = 3 + rand.nextInt(4);
          for (int i = 0; i < count; i++) {
            final day = 2 + rand.nextInt(daysInMonth - 1);
            final d = DateTime(year, month, day, 18, rand.nextInt(59));
            final amount = 20 + rand.nextInt(80) + rand.nextDouble();
            await DatabaseService.instance.createTransaction(ff.Transaction(
              id: uuid.v4(),
              amount: double.parse(amount.toStringAsFixed(2)),
              categoryId: groceries.id,
              date: d,
              description: 'Groceries ${ymd(d)}',
            ));
          }
        }

        // Transportation: 6-12 entries
        final transport = byId('transportation');
        if (transport != null && transport.id != 'none') {
          final count = 6 + rand.nextInt(7);
          for (int i = 0; i < count; i++) {
            final day = 1 + rand.nextInt(daysInMonth);
            final d = DateTime(year, month, day, 8 + rand.nextInt(10), rand.nextInt(59));
            final amount = 3 + rand.nextInt(15) + rand.nextDouble();
            await DatabaseService.instance.createTransaction(ff.Transaction(
              id: uuid.v4(),
              amount: double.parse(amount.toStringAsFixed(2)),
              categoryId: transport.id,
              date: d,
              description: 'Transport ${ymd(d)}',
            ));
          }
        }

        // Entertainment: 2-5 entries
        final entertainment = byId('entertainment');
        if (entertainment != null && entertainment.id != 'none') {
          final count = 2 + rand.nextInt(4);
          for (int i = 0; i < count; i++) {
            final day = 1 + rand.nextInt(daysInMonth);
            final d = DateTime(year, month, day, 20, rand.nextInt(59));
            final amount = 10 + rand.nextInt(60) + rand.nextDouble();
            await DatabaseService.instance.createTransaction(ff.Transaction(
              id: uuid.v4(),
              amount: double.parse(amount.toStringAsFixed(2)),
              categoryId: entertainment.id,
              date: d,
              description: 'Entertainment ${ymd(d)}',
            ));
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample year transactions with dates added.')),
        );
        SettingsService.instance.notifyDataChanged();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add samples: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  DateTime _startOfPeriod(DateTime now) {
    switch (_period) {
      case _Period.monthly:
        return DateTime(now.year, now.month, 1);
      case _Period.yearly:
        return DateTime(now.year, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Palettes
    final incomePalette = <Color>[
      Colors.green.shade700,
      Colors.green,
      Colors.lightGreen,
      Colors.teal,
      Colors.greenAccent,
      Colors.lightGreenAccent,
      Colors.tealAccent,
    ];

    final expensePalette = <Color>[
      Colors.red.shade700,
      Colors.red,
      Colors.deepOrange,
      Colors.orange,
      Colors.redAccent,
      Colors.deepOrangeAccent,
      Colors.pink.shade400,
    ];

    return FutureBuilder<(List<ff.Transaction>, List<Category>)>(
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (allTxns, cats) = snapshot.data!;

        final now = DateTime.now();
        final start = _startOfPeriod(now);
        final txns = allTxns.where((t) => !t.date.isBefore(start) && !t.date.isAfter(now)).toList();

        double totalIncome = 0, totalExpense = 0;
        final incomeByCat = <String, double>{};
        final expenseByCat = <String, double>{};
        for (final t in txns) {
          final cat = cats.firstWhere(
            (c) => c.id == t.categoryId,
            orElse: () => const Category(id: 'unknown', name: 'Unknown', type: CategoryType.expense),
          );
          if (cat.type == CategoryType.income) {
            totalIncome += t.amount;
            incomeByCat.update(cat.name, (v) => v + t.amount, ifAbsent: () => t.amount);
          } else {
            totalExpense += t.amount;
            expenseByCat.update(cat.name, (v) => v + t.amount, ifAbsent: () => t.amount);
          }
        }

        final periodLabel = _period == _Period.monthly ? 'This Month' : 'This Year';

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // Centered period selector (wider)
              Center(
                child: SizedBox(
                  width: 320,
                  child: SegmentedButton<_Period>(
                    segments: const [
                      ButtonSegment(value: _Period.monthly, label: Text('Monthly')),
                      ButtonSegment(value: _Period.yearly, label: Text('Yearly')),
                    ],
                    selected: {_period},
                    onSelectionChanged: (selection) {
                      setState(() { _period = selection.first; });
                    },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(MaterialState.selected)) {
                          return Theme.of(context).colorScheme.primary.withOpacity(0.15);
                        }
                        return null;
                      }),
                      foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(MaterialState.selected)) {
                          return Theme.of(context).colorScheme.primary;
                        }
                        return null;
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(periodLabel, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _isSeeding ? null : _generateSampleYearData,
                  icon: _isSeeding
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_graph),
                  label: const Text('Add Sample Year Transactions'),
                ),
              ),
              const SizedBox(height: 16),

              _StorageLikeSection(
                title: 'Income',
                total: totalIncome,
                byCategory: incomeByCat,
                palette: incomePalette,
                barBackground: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              ),

              const SizedBox(height: 20),

              _StorageLikeSection(
                title: 'Expenses',
                total: totalExpense,
                byCategory: expenseByCat,
                palette: expensePalette,
                barBackground: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StorageLikeSection extends StatelessWidget {
  final String title;
  final double total;
  final Map<String, double> byCategory;
  final List<Color> palette;
  final Color barBackground;

  const _StorageLikeSection({
    required this.title,
    required this.total,
    required this.byCategory,
    required this.palette,
    required this.barBackground,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Group small categories into "Other" to keep it clean
    final List<MapEntry<String, double>> top;
    final MapEntry<String, double>? other;
    if (entries.length <= 6) {
      top = entries;
      other = null;
    } else {
      top = entries.take(6).toList();
      final restSum = entries.skip(6).fold<double>(0, (s, e) => s + e.value);
      other = MapEntry('Other', restSum);
    }

    final displayEntries = [
      ...top,
      if (other != null && other.value > 0) other,
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(SettingsService.instance.formatCurrency(total), style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            _SegmentBar(
              total: total,
              entries: [
                for (int i = 0; i < displayEntries.length; i++)
                  _Segment(label: displayEntries[i].key, value: displayEntries[i].value, color: palette[i % palette.length])
              ],
              background: barBackground,
            ),
            const SizedBox(height: 12),
            if (total == 0)
              const Text('No data to display.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < displayEntries.length; i++)
                    _LegendDot(
                      color: palette[i % palette.length],
                      label: '${displayEntries[i].key} • ${SettingsService.instance.formatCurrency(displayEntries[i].value)} • ${_pct(displayEntries[i].value, total)}%',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _pct(double v, double total) {
    if (total <= 0) return '0';
    final p = (v / total) * 100;
    return p.toStringAsFixed(p >= 10 ? 0 : 1);
  }
}

class _SegmentBar extends StatelessWidget {
  final double total;
  final List<_Segment> entries;
  final Color background;
  const _SegmentBar({required this.total, required this.entries, required this.background});

  @override
  Widget build(BuildContext context) {
    const baseFlex = 1000; // for proportional widths
    final effectiveEntries = entries.where((e) => e.value > 0).toList();
    if (total <= 0 || effectiveEntries.isEmpty) {
      return Container(
        height: 18,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }

    // Compute flex for each segment; ensure we use all baseFlex via residual adjustment
    final flexes = <int>[];
    int used = 0;
    for (int i = 0; i < effectiveEntries.length; i++) {
      if (i == effectiveEntries.length - 1) {
        flexes.add(baseFlex - used);
      } else {
        final f = ((effectiveEntries[i].value / total) * baseFlex).round();
        final clamped = f.clamp(1, baseFlex - used - (effectiveEntries.length - i - 1));
        flexes.add(clamped);
        used += clamped;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 18,
        color: background,
        child: Row(
          children: [
            for (int i = 0; i < effectiveEntries.length; i++)
              Expanded(
                flex: flexes[i],
                child: Container(color: effectiveEntries[i].color),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment {
  final String label;
  final double value;
  final Color color;
  const _Segment({required this.label, required this.value, required this.color});
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
