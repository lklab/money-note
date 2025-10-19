import 'package:flutter/material.dart';
import 'package:money_note/data/budget_indexer.dart';
import 'package:money_note/data/record_storage.dart';
import 'package:money_note/widgets/record_item.dart';

class RecordListPage extends StatelessWidget {
  final List<Record> records;
  final BudgetIndexer? budgetIndexer;

  const RecordListPage({
    super.key,
    required this.records,
    this.budgetIndexer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
            ),
            itemCount: records.length,
            itemBuilder: (context, index) {
              return RecordItem(
                record: records[index],
                budgetIndexer: budgetIndexer,
              );
            },
          ),
        ),
      ),
    );
  }
}
