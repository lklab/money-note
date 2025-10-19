import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:money_note/data/budget_indexer.dart';
import 'package:money_note/data/record_storage.dart';
import 'package:money_note/pages/record_list_page.dart';
import 'package:money_note/utils/utils.dart';

class BudgetItemRaw extends StatelessWidget {
  final bool isGroup;
  final String name;
  final List<Record> records;
  final int amount;
  final int used;
  final int remain;
  final BudgetIndexer? budgetIndexer;
  final void Function()? onTap;
  final bool onlyShowRemain;

  const BudgetItemRaw({
    super.key,
    required this.isGroup,
    required this.name,
    required this.records,
    required this.amount,
    required this.used,
    required this.remain,
    this.budgetIndexer,
    this.onTap,
    this.onlyShowRemain = false,
  });

  Widget _text(String text, Alignment alignment, TextStyle style) {
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          style: style,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    TextStyle nameTextStyle = isGroup ?
      Theme.of(context).textTheme.bodyLarge!.copyWith(
        color: Theme.of(context).primaryColor,
        fontWeight: FontWeight.w500,
      ) :
      Theme.of(context).textTheme.bodyMedium!;

    TextStyle moneyTextStyle = Theme.of(context).textTheme.bodySmall!;

    double textSpacing = 4;

    return ListTile(
      title: Row(
        children: [
          SizedBox(
            width: 150,
            child: Row(
              children: [
                if (isGroup)
                FaIcon(
                  FontAwesomeIcons.folderOpen,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                if (isGroup)
                SizedBox(width: 8),
                _text(name, Alignment.centerLeft, nameTextStyle),
              ],
            ),
          ),
          SizedBox(width: textSpacing),
          Expanded(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) {
                      return RecordListPage(
                        records: records,
                        budgetIndexer: budgetIndexer,
                      );
                    },
                  ),
                );
              },
              style: ButtonStyle(
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                minimumSize: const WidgetStatePropertyAll(Size(0, 0)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerRight,
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              child: Row(
                children: [
                  Text( // 높이 채우기용
                    '',
                    style: nameTextStyle,
                  ),
                  _text(onlyShowRemain ? '' : Utils.formatMoney(amount), Alignment.centerRight, moneyTextStyle),
                  SizedBox(width: textSpacing),
                  _text(onlyShowRemain ? '' : Utils.formatMoney(used), Alignment.centerRight, moneyTextStyle),
                  SizedBox(width: textSpacing),
                  _text(Utils.formatMoney(remain), Alignment.centerRight, moneyTextStyle.copyWith(
                    color: Utils.getMoneyColor(remain, useBlue: true),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
      minVerticalPadding: 0.0,
      visualDensity: const VisualDensity(vertical: -4),
      onTap: onTap,
    );
  }
}
