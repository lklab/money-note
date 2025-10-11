import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_note/data/budget_indexer.dart';
import 'package:money_note/data/record_storage.dart';
import 'package:money_note/pages/record_edit_page.dart';
import 'package:money_note/utils/style.dart';
import 'package:money_note/utils/utils.dart';

class RecordItem extends StatelessWidget {
  final Record record;
  final BudgetIndexer budgetIndexer;
  final bool showDay;
  final Function()? onUpdated;

  const RecordItem({
    super.key,
    required this.record,
    required this.budgetIndexer,
    this.showDay = true,
    this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    String? budgetName = budgetIndexer.budgetMap[record.budget]?.name;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.surfaceDim, width: 1),
        ),
      ),
      child: ListTile(
        title: Row(
          children: [
            Column(
              children: [
                if (showDay)
                Text(
                  DateFormat('M.d').format(record.dateTime),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  DateFormat('HH:mm').format(record.dateTime),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.content,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (budgetName != null)
                  Text(
                    budgetName,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.0),
            Text(
              Utils.formatMoney(record.amount),
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: record.amount == 0 ? Style.neutralColor : record.kind == RecordKind.income ? Style.positiveColor : Style.negativeColor,
              ),
            ),
          ],
        ),
        // dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
        minVerticalPadding: 0.0,
        visualDensity: const VisualDensity(vertical: -4),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) {
                return RecordEditPage(
                  record: record,
                  budgetIndexer: budgetIndexer,
                );
              },
            ),
          );

          if (changed == true && onUpdated != null) {
            onUpdated!();
          }
        },
      ),
    );
  }
}
