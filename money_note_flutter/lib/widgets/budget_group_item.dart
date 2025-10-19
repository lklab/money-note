import 'package:flutter/material.dart';
import 'package:money_note/data/budget_records.dart';
import 'package:money_note/data/budget_storage.dart';
import 'package:money_note/data/record_storage.dart';
import 'package:money_note/pages/budget_group_edit_page.dart';
import 'package:money_note/widgets/budget_item_raw.dart';

class BudgetGroupItem extends StatelessWidget {
  final DateTime month;
  final BudgetGroup budgetGroup;
  final BudgetRecords budgetRecords;
  final Function()? onUpdated;

  const BudgetGroupItem({
    super.key,
    required this.month,
    required this.budgetGroup,
    required this.budgetRecords,
    this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final allRecords = budgetGroup.budgets
      .expand((b) => budgetRecords.recordMap[b.id] ?? const <Record>[])
      .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final (amount, used, remain) = budgetRecords.budgetGroupAmounts[budgetGroup.id] ?? (0, 0, 0);

    return BudgetItemRaw(
      isGroup: true,
      name: budgetGroup.name,
      records: allRecords,
      amount: amount,
      used: used,
      remain: remain,
      budgetIndexer: budgetRecords.budgetIndexer,
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => BudgetGroupEditPage(
              month: month,
              budgetGroup: budgetGroup,
            ),
          ),
        );

        if (changed == true && onUpdated != null) {
          onUpdated!();
        }
      },
    );
  }
}
