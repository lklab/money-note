import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_note_flutter/data/record_storage.dart';
import 'package:money_note_flutter/utils/style.dart';
import 'package:money_note_flutter/utils/utils.dart';

class RecordItem extends StatelessWidget {
  final Record record;
  final bool showDay;

  const RecordItem({
    super.key,
    required this.record,
    this.showDay = true,
  });

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    record.budget,
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
        onTap: () {
          
        },
      ),
    );
  }
}
