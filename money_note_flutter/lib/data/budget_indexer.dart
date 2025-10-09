import 'package:money_note_flutter/data/budget_storage.dart';

class BudgetIndexer {
  final List<Budget> _budgets = [];
  List<Budget> get budgets => _budgets;

  final Map<String, Budget> _budgetMap = {};
  Map<String, Budget> get budgetMap => _budgetMap;

  BudgetIndexer(MonthlyBudget monthlyBudget) {
    for (BudgetGroup group in monthlyBudget.groups) {
      for (Budget budget in group.budgets) {
        _budgets.add(budget);
        _budgetMap[budget.id] = budget;
      }
    }
  }
}
