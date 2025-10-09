import 'package:money_note_flutter/data/budget_indexer.dart';
import 'package:money_note_flutter/data/budget_storage.dart';
import 'package:money_note_flutter/data/record_storage.dart';

class BudgetRecords {
  late BudgetIndexer _budgetIndexer;
  BudgetIndexer get budgetIndexer => _budgetIndexer;

  final Map<String, List<Record>> _recordMap = {};
  Map<String, List<Record>> get recordMap => _recordMap;

  final List<Record> _noBudgetRecords = [];
  List<Record> get noBudgetRecords => _noBudgetRecords;

  int _cashIncome = 0; int get cashIncome => _cashIncome;
  int _cashExpense = 0; int get cashExpense => _cashExpense;
  int _cashDiff = 0; int get cashDiff => _cashDiff;

  int _capitalIncome = 0; int get capitalIncome => _capitalIncome;
  int _capitalExpense = 0; int get capitalExpense => _capitalExpense;
  int _capitalDiff = 0; int get capitalDiff => _capitalDiff;

  int _noBudgetUsed = 0;
  int get noBudgetUsed => _noBudgetUsed;

  final Map<String, (int, int, int)> _budgetGroupAmounts = {};
  Map<String, (int, int, int)> get budgetGroupAmounts => _budgetGroupAmounts;

  final Map<String, int> _budgetAmounts = {};
  Map<String, int> get budgetAmounts => _budgetAmounts;

  BudgetRecords(MonthlyBudget monthlyBudget, List<Record> records) {
    _budgetIndexer = BudgetIndexer(monthlyBudget);

    for (Record record in records) {
      String budgetId = record.budget;
      int amount = record.kind == RecordKind.income ? record.amount : -record.amount;

      if (_budgetIndexer.budgetMap.containsKey(budgetId)) {
        if (!_recordMap.containsKey(budgetId)) {
          _recordMap[budgetId] = [];
        }
        _recordMap[budgetId]!.add(record);

        Budget budget = _budgetIndexer.budgetMap[budgetId]!;
        int used = _budgetAmounts[budgetId] ?? 0;
        used += budget.kind == BudgetKind.income ? amount : -amount;
        _budgetAmounts[budgetId] = used;

        switch (budget.assetType) {
          case BudgetAssetType.cash:
            switch (record.kind) {
              case RecordKind.income: _cashIncome += record.amount; break;
              case RecordKind.expense: _cashExpense += record.amount; break;
            }
            break;
          case BudgetAssetType.capital:
            switch (record.kind) {
              case RecordKind.income: _capitalIncome += record.amount; break;
              case RecordKind.expense: _capitalExpense += record.amount; break;
            }
            break;
        }

      } else {
        _noBudgetRecords.add(record);
        _noBudgetUsed += amount;
        switch (record.kind) {
          case RecordKind.income: _cashIncome += record.amount; break;
          case RecordKind.expense: _cashExpense += record.amount; break;
        }
      }
    }

    for (BudgetGroup group in monthlyBudget.groups) {
      int amount = 0;
      int used = 0;

      for (Budget budget in group.budgets) {
        amount += budget.amount;
        used += _budgetAmounts[budget.id] ?? 0;
      }

      _budgetGroupAmounts[group.id] = (amount, used, amount - used);
    }

    _cashDiff = _cashIncome - _cashExpense;
    _capitalDiff = _capitalIncome - _capitalExpense;
  }
}
