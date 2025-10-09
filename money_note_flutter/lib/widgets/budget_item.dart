import 'package:flutter/material.dart';
import 'package:money_note_flutter/data/budget_records.dart';
import 'package:money_note_flutter/data/budget_storage.dart';
import 'package:money_note_flutter/pages/budget_edit_page.dart';
import 'package:money_note_flutter/widgets/budget_item_raw.dart';

class BudgetItem extends StatelessWidget {
  final Budget budget;
  final BudgetGroup group;
  final DateTime month;
  final List<BudgetGroup> groups;
  final BudgetRecords budgetRecords;
  final Function()? onUpdated;

  const BudgetItem({
    super.key,
    required this.budget,
    required this.group,
    required this.month,
    required this.groups,
    required this.budgetRecords,
    this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    int amount = budget.amount;
    int used = budgetRecords.budgetAmounts[budget.id] ?? 0;
    int remain = amount - used;

    return BudgetItemRaw(
      isGroup: false,
      name: budget.name,
      amount: amount,
      used: used,
      remain: remain,
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => BudgetEditPage(
              month: month,
              groups: groups,
              budget: budget,
              group: group,
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
