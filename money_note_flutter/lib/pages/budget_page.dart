import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:money_note/data/backup_manager.dart';
import 'package:money_note/data/budget_records.dart';
import 'package:money_note/data/budget_storage.dart';
import 'package:money_note/data/record_storage.dart';
import 'package:money_note/pages/budget_edit_page.dart';
import 'package:money_note/pages/budget_group_edit_page.dart';
import 'package:money_note/utils/utils.dart';
import 'package:money_note/widgets/budget_group_item.dart';
import 'package:money_note/widgets/budget_item.dart';
import 'package:money_note/widgets/budget_item_raw.dart';
import 'package:money_note/widgets/month_navigator.dart';
import 'package:money_note/widgets/wands_button.dart';

class BudgetPage extends StatefulWidget {
  final int index;
  final ValueListenable<int> indexListenable;

  const BudgetPage({
    super.key,
    required this.index,
    required this.indexListenable,
  });

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  late int _lastIndex;
  late final VoidCallback _listener;

  DateTime _currentMonth = DateTime.now();
  MonthlyBudget? _monthlyBudget;
  MonthlyBudget? _prevBudget;
  BudgetRecords? _budgetRecords;

  List<DragAndDropList> _lists = [];

  @override
  void initState() {
    super.initState();

    _lastIndex = widget.indexListenable.value;
    _listener = () {
      final now = widget.indexListenable.value;
      if (now == widget.index && _lastIndex != now) {
        _onPageShow();
      }
      if (_lastIndex == widget.index && now != widget.index) {
        _onPageHide();
      }
      _lastIndex = now;
    };
    widget.indexListenable.addListener(_listener);

    _updatePage();
  }

  @override
  void dispose() {
    widget.indexListenable.removeListener(_listener);
    super.dispose();
  }

  void _onPageShow() {
    _updatePage();
  }

  void _onPageHide() { }

  void _updatePage() {
    _setMonth(_currentMonth);
  }

  void _setMonth(DateTime month) async {
    final records = await RecordStorage().getRecordsOfMonth(month);
    final monthlyBudget = await BudgetStorage().getMonthlyBudget(month);

    MonthlyBudget? prevBudget;
    if (monthlyBudget.groups.isEmpty) {
      prevBudget = await BudgetStorage().getMonthlyBudget(DateTime(month.year, month.month - 1));
    }

    _backup(_currentMonth, records, monthlyBudget);

    setState(() {
      _currentMonth = month;
      _monthlyBudget = monthlyBudget;
      _prevBudget = prevBudget;
      _budgetRecords = BudgetRecords(monthlyBudget, records);

      _updateLists(records, monthlyBudget);
    });
  }

  void _updateLists(List<Record> records, MonthlyBudget monthlyBudget) {
    _lists = [];

    final groups = monthlyBudget.groups;

    for (BudgetGroup group in groups) {
      _lists.add(
        DragAndDropList(
          header: BudgetGroupItem(
            month: _currentMonth,
            budgetGroup: group,
            budgetRecords: _budgetRecords!,
            onUpdated: _updatePage,
          ),
          children: [
            for (final budget in group.budgets)
            DragAndDropItem(
              child: BudgetItem(
                budget: budget,
                group: group,
                month: _currentMonth,
                groups: groups,
                budgetRecords: _budgetRecords!,
                onUpdated: _updatePage,
              ),
            )
          ],
          contentsWhenEmpty: Builder(
            builder: (ctx) => Text(
              '예산이 없습니다.',
              style: Theme.of(ctx).textTheme.bodyMedium!.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        )
      );
    }
  }

  void _backup(DateTime month, List<Record> records, MonthlyBudget monthlyBudget) async {
    final recordStorage = RecordStorage();
    final budgetStorage = BudgetStorage();

    if (recordStorage.isDirty || budgetStorage.isDirty) {
      recordStorage.clearDirty();
      budgetStorage.clearDirty();

      try {
        await BackupManager().uploadBackupDataForMonth(_currentMonth, records: records, monthlyBudgets: [monthlyBudget]);
      } catch (e) {
        if (mounted) {
          Utils.showPopup(context, '통신 실패', '서버와 통신하는 데에 실패했습니다.\n${e.toString()}}');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCopyAvailable =
      _monthlyBudget != null &&
      _prevBudget != null &&
      _monthlyBudget!.groups.isEmpty &&
      _prevBudget!.groups.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          MonthNavigator(
            initialValue: DateTime.now(),
            onChange: (month) {
              _setMonth(month);
            },
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            border: TableBorder.all(
              color: Theme.of(context).colorScheme.surface,
              width: 1.0,
            ),
            children: [
              Utils.getTableRowHeader(context, ['현금 수입', '현금 지출', '현금 수지']),
              Utils.getTableRowContent(
                context,
                [
                  _budgetRecords?.cashIncome ?? 0,
                  _budgetRecords?.cashExpense ?? 0,
                  _budgetRecords?.cashDiff ?? 0,
                ],
                useBlues: [false, false, true]),
              Utils.getTableRowHeader(context, ['자본 수입', '자본 지출', '자본 수지']),
              Utils.getTableRowContent(
                context,
                [
                  _budgetRecords?.capitalIncome ?? 0,
                  _budgetRecords?.capitalExpense ?? 0,
                  _budgetRecords?.capitalDiff ?? 0,
                ],
                useBlues: [false, false, true]),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            child: BudgetItemRaw(
              isGroup: false,
              name: '예산 외',
              amount: 0,
              used: 0,
              remain: _budgetRecords?.noBudgetUsed ?? 0,
              onlyShowRemain: true,
            ),
          ),
          Expanded(
            child: DragAndDropLists(
              children: _lists,
              onItemReorder: (oldItemIndex, oldListIndex, newItemIndex, newListIndex) async {
                final oldGroup = _monthlyBudget!.groups[oldListIndex];
                final newGroup = _monthlyBudget!.groups[newListIndex];
                final budget = oldGroup.budgets[oldItemIndex];

                await BudgetStorage().moveBudget(
                  month: _currentMonth,
                  budgetId: budget.id,
                  fromGroupId: oldGroup.id,
                  toGroupId: newGroup.id,
                  toIndex: newItemIndex,
                );

                _updatePage();
              },
              onListReorder: (oldListIndex, newListIndex) async {
                final group = _monthlyBudget!.groups[oldListIndex];

                await BudgetStorage().moveGroup(
                  month: _currentMonth,
                  groupId: group.id,
                  toIndex: newListIndex,
                );

                _updatePage();
              },
              listPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              lastListTargetSize: 64.0,
              itemDecorationWhileDragging: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(blurRadius: 8, spreadRadius: 1)],
              ),
              contentsWhenEmpty: isCopyAvailable ?
                WandsButton(
                  onPressed: () async {
                    DateTime prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                    await BudgetStorage().cloneMonthlyBudget(
                      fromMonth: prevMonth,
                      toMonth: _currentMonth,
                    );

                    _updatePage();
                  },
                  isFilled: false,
                  text: '이전 달에서 예산 복사하기',
                ) :
                Text(
                  '예산이 없습니다.',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        spacing: 10,
        spaceBetweenChildren: 10,
        children: [
          SpeedDialChild(
            child: const FaIcon(FontAwesomeIcons.receipt),
            label: '예산 추가',
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            onTap: () async {
              if (_monthlyBudget == null || _monthlyBudget!.groups.isEmpty) {
                Utils.showSnack(context, '예산을 추가하려면 예산그룹이 적어도 하나 이상 있어야 합니다.');
                return;
              }

              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => BudgetEditPage(
                    month: _currentMonth,
                    groups: _monthlyBudget!.groups,
                  ),
                ),
              );

              if (changed == true) {
                _updatePage();
              }
            },
          ),
          SpeedDialChild(
            child: const FaIcon(FontAwesomeIcons.folderOpen),
            label: '예산그룹 추가',
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            onTap: () async {
              if (_monthlyBudget == null) {
                return;
              }

              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => BudgetGroupEditPage(month: _currentMonth),
                ),
              );

              if (changed == true) {
                _updatePage();
              }
            },
          ),
        ],
      ),
    );
  }
}
