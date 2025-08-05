import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Tracker',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: BudgetHomePage(),
    );
  }
}

class BudgetEntry {
  String type;
  String category;
  double amount;
  String description;
  DateTime date;

  BudgetEntry(this.type, this.category, this.amount, this.description, this.date);

  Map<String, dynamic> toJson() => {
        'type': type,
        'category': category,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String(),
      };

  static BudgetEntry fromJson(Map<String, dynamic> json) => BudgetEntry(
        json['type'],
        json['category'],
        json['amount'],
        json['description'],
        DateTime.parse(json['date']),
      );
}

class BudgetHomePage extends StatefulWidget {
  @override
  _BudgetHomePageState createState() => _BudgetHomePageState();
}

class _BudgetHomePageState extends State<BudgetHomePage> {
  List<BudgetEntry> entries = [];
  double income = 0;
  double expense = 0;
  Map<String, double> monthlyIncome = {};
  Map<String, double> monthlyExpense = {};

  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _type = 'Expense';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('entries') ?? [];
    setState(() {
      entries = data.map((e) => BudgetEntry.fromJson(json.decode(e))).toList();
      _calculateTotals();
    });
  }

  void _saveEntry() async {
    final prefs = await SharedPreferences.getInstance();
    final amount = double.tryParse(_amountController.text);
    if (_categoryController.text.isEmpty || amount == null) return;

    final entry = BudgetEntry(
      _type,
      _categoryController.text,
      amount,
      _descController.text,
      DateTime.now(),
    );
    entries.add(entry);
    await prefs.setStringList(
      'entries',
      entries.map((e) => json.encode(e.toJson())).toList(),
    );
    _categoryController.clear();
    _amountController.clear();
    _descController.clear();
    setState(() => _calculateTotals());
  }

  void _calculateTotals() {
    income = 0;
    expense = 0;
    monthlyIncome.clear();
    monthlyExpense.clear();

    for (var e in entries) {
      String monthKey = DateFormat('yyyy-MM').format(e.date);
      if (e.type == 'Income') {
        income += e.amount;
        monthlyIncome[monthKey] = (monthlyIncome[monthKey] ?? 0) + e.amount;
      } else {
        expense += e.amount;
        monthlyExpense[monthKey] = (monthlyExpense[monthKey] ?? 0) + e.amount;
      }
    }
  }

  List<BarChartGroupData> _buildBarGroups() {
    final allMonths = {...monthlyIncome.keys, ...monthlyExpense.keys}.toList()
      ..sort();

    return allMonths.map((month) {
      final i = allMonths.indexOf(month);
      final incomeVal = monthlyIncome[month] ?? 0;
      final expenseVal = monthlyExpense[month] ?? 0;

      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: incomeVal, color: Colors.green, width: 8),
        BarChartRodData(toY: expenseVal, color: Colors.red, width: 8),
      ], showingTooltipIndicators: [0, 1]);
    }).toList();
  }

  List<String> _getSortedMonthLabels() {
    final allMonths = {...monthlyIncome.keys, ...monthlyExpense.keys}.toList();
    allMonths.sort();
    return allMonths;
  }

  Widget _buildBarChart() {
    final monthLabels = _getSortedMonthLabels();
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= monthLabels.length) return SizedBox();
                  final label = monthLabels[index].split('-')[1];
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(label),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _buildBarGroups(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;

    return Scaffold(
      appBar: AppBar(title: Text('Budget Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Balance: RM${balance.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Income: RM${income.toStringAsFixed(2)}'),
            Text('Expenses: RM${expense.toStringAsFixed(2)}'),
            SizedBox(height: 16),
            _buildBarChart(),
            Divider(),
            Row(
              children: [
                Text('Type:'),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: _type,
                  items: ['Income', 'Expense']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _type = val!),
                ),
              ],
            ),
            TextField(controller: _categoryController, decoration: InputDecoration(labelText: 'Category')),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            TextField(controller: _descController, decoration: InputDecoration(labelText: 'Description')),
            ElevatedButton(onPressed: _saveEntry, child: Text('Add Entry')),
          ],
        ),
      ),
    );
  }
}
