import 'package:flutter/material.dart';
import 'package:money_note/data/record_storage.dart';
import 'package:money_note/utils/utils.dart';

class CalendarDay extends StatelessWidget {
  final int day;
  final List<Record> records;
  final int selectedDay;
  final void Function(int) onTab;

  const CalendarDay({
    super.key,
    required this.day,
    required this.records,
    required this.selectedDay,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    bool isEmpty = day == 0;
    int totalIncome = 0;
    int totalExpense = 0;
    int totalDiff = 0;

    if (!isEmpty) {

      for (Record record in records) {
        switch (record.kind) {
          case RecordKind.income :
            totalIncome += record.amount;
            break;
          case RecordKind.expense :
            totalExpense += record.amount;
            break;
        }
      }

      totalDiff = totalIncome - totalExpense;
    }

    return GestureDetector(
      onTap: () {
        if (!isEmpty) {
          onTab(day);
        }
      },
      child: Container(
        color: isEmpty ?
          Theme.of(context).colorScheme.surfaceDim :
          day == selectedDay ?
            Theme.of(context).colorScheme.secondaryFixedDim :
            Theme.of(context).colorScheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  isEmpty ? '' : '$day',
                  textAlign: TextAlign.left,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(width: 2),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      isEmpty || totalDiff == 0 ? '' : Utils.formatMoney(totalDiff),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Utils.getMoneyColor(totalDiff, useBlue: true),
                        fontSize: 10.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.cover,
                child: Text(
                  isEmpty || totalIncome == 0 ? '' : Utils.formatMoney(totalIncome),
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Utils.getMoneyColor(totalIncome, useBlue: true),
                    fontSize: 10.0,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isEmpty || totalExpense == 0 ? '' : Utils.formatMoney(totalExpense),
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Utils.getMoneyColor(-totalExpense, useBlue: true),
                    fontSize: 10.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
