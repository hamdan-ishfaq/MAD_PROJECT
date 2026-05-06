import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/local_backend_service.dart';
import 'package:tripgenie/core/services/ai_service.dart';

class ExpenseTrackerScreen extends StatefulWidget {
  final String tripId;
  final String tripName;
  const ExpenseTrackerScreen({super.key, required this.tripId, required this.tripName});

  @override
  State<ExpenseTrackerScreen> createState() => _ExpenseTrackerScreenState();
}

class _ExpenseTrackerScreenState extends State<ExpenseTrackerScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;

  static const _categories = ['Food', 'Transport', 'Accommodation', 'Activities', 'Shopping', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final expenses = await LocalBackendService.getExpenses(widget.tripId);
    if (mounted) setState(() { _expenses = expenses; _isLoading = false; });
  }

  double get _total => _expenses.fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));

  void _showAddExpenseDialog() {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final splitWithCtrl = TextEditingController();
    String category = 'Food';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Expense'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: category,
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setDialogState(() => category = v ?? 'Food'),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Dinner at Monal')),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ ')),
            const SizedBox(height: 12),
            TextField(controller: splitWithCtrl, decoration: const InputDecoration(labelText: 'Split With (optional)', hintText: 'e.g. Alice, Bob')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) return;
                final user = await AuthService.loadUser();
                
                final splitNames = splitWithCtrl.text.trim();
                final splitType = splitNames.isEmpty ? 'equal' : 'split:$splitNames';
                
                await LocalBackendService.addExpense(
                  tripId: widget.tripId, userId: user?.id ?? 'guest', userName: user?.name ?? 'You',
                  category: category, description: descCtrl.text.trim(), amount: amount,
                  splitType: splitType,
                );
                // Mock adding notifications to others
                if (splitNames.isNotEmpty) {
                  for (var name in splitNames.split(',')) {
                    await LocalBackendService.addNotification(
                      userId: 'guest', // MVP mock
                      title: 'New Expense Added',
                      body: '${user?.name ?? 'You'} added \$${amount.toStringAsFixed(2)} for ${descCtrl.text.trim()}',
                    );
                  }
                }
                
                Navigator.pop(ctx);
                _loadExpenses();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.directions_car;
      case 'accommodation': return Icons.hotel;
      case 'activities': return Icons.hiking;
      case 'shopping': return Icons.shopping_bag;
      default: return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text(widget.tripName, style: const TextStyle(fontWeight: FontWeight.w700))),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadExpenses,
        child: Column(children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20), color: Colors.white,
            child: Column(children: [
              const Text('Total Expenses', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('\$${_total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showBudgetAdvisorDialog,
                    icon: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                    label: const Text('AI Budget'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showSettleUpDialog,
                    icon: const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppColors.accent),
                    label: const Text('Settle Up'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent)),
                  ),
                ],
              ),
            ]),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? ListView(children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.receipt_long, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('No expenses yet', style: TextStyle(color: AppColors.textSecondary)),
                        ])),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _expenses.length,
                        itemBuilder: (_, i) {
                          final e = _expenses[i];
                          final cat = e['category'] as String? ?? 'Other';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: AppColors.primaryLight, child: Icon(_iconForCategory(cat), color: AppColors.primary, size: 20)),
                              title: Text(e['description'] as String? ?? cat, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text('$cat · ${e['paid_by'] ?? 'You'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              trailing: Text('\$${(e['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showBudgetAdvisorDialog() {
    final budgetCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.auto_awesome, color: AppColors.primary), SizedBox(width: 8), Text('AI Budget Advisor')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How much money do you have left for today?', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(controller: budgetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Remaining Budget', prefixText: '\$ ')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final budget = double.tryParse(budgetCtrl.text);
              if (budget == null || budget <= 0) return;
              Navigator.pop(ctx);
              _fetchAndShowAdvice(budget);
            },
            child: const Text('Get Advice'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAndShowAdvice(double budget) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    final advice = await AIService.getBudgetAdvice(destination: widget.tripName, remainingBudget: budget);
    if (!mounted) return;
    Navigator.pop(context); // Close loading
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Plan for \$$budget'),
        content: SingleChildScrollView(child: Text(advice, style: const TextStyle(fontSize: 13, height: 1.5))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showSettleUpDialog() {
    final Map<String, double> balances = {}; // Positive means they are owed, Negative means they owe

    for (var e in _expenses) {
      final payer = e['paid_by'] as String? ?? 'You';
      final amount = (e['amount'] as num?)?.toDouble() ?? 0.0;
      final splitType = e['split_type'] as String? ?? 'equal';
      
      balances[payer] = (balances[payer] ?? 0.0) + amount;
      
      if (splitType.startsWith('split:')) {
        final names = splitType.substring(6).split(',').map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
        if (!names.contains(payer)) names.add(payer); // Payer is included in split usually
        final splitShare = amount / names.length;
        for (var name in names) {
          balances[name] = (balances[name] ?? 0.0) - splitShare;
        }
      } else {
        // Simple equal split fallback
        // To be accurate we'd need total members. For MVP, we'll assume 1 if 'equal' with no other users.
        balances[payer] = (balances[payer] ?? 0.0) - amount; // Cancels out, just tracking who paid what
      }
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settle Up'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Expenses: \$${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Balances:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...balances.entries.where((e) => e.value.abs() > 0.01).map((e) {
              final balance = e.value;
              final balanceText = balance > 0 ? 'is owed \$${balance.toStringAsFixed(2)}' : 'owes \$${(-balance).toStringAsFixed(2)}';
              final color = balance > 0 ? Colors.green : Colors.red;
              return Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('${e.key} $balanceText', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
              );
            }).toList(),
            if (balances.entries.where((e) => e.value.abs() > 0.01).isEmpty)
              const Text('All settled up!', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}
