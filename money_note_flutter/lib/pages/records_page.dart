import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:money_note/data/backup_manager.dart';
import 'package:money_note/data/budget_indexer.dart';
import 'package:money_note/data/budget_storage.dart';
import 'package:money_note/data/record_storage.dart';
import 'package:money_note/pages/record_edit_page.dart';
import 'package:money_note/utils/utils.dart';
import 'package:money_note/widgets/calendar_day.dart';
import 'package:money_note/widgets/month_navigator.dart';
import 'package:money_note/widgets/record_item.dart';

class RecordsPage extends StatefulWidget {
  final int index;
  final ValueListenable<int> indexListenable;

  const RecordsPage({
    super.key,
    required this.index,
    required this.indexListenable,
  });

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  late int _lastIndex;
  late final VoidCallback _listener;

  DateTime _currentMonth = DateTime.now();
  List<Record> _records = [];
  List<List<int>> _dayCalendar = List.generate(6, (_) => List.filled(7, 0));
  List<List<List<Record>>> _recordCalendar = List.generate(6, (_) => List.generate(7, (_) => []));
  BudgetIndexer? _budgetIndexer;

  bool _currentDayInitialized = false;
  int _currentDay = 1;
  int _startWeekDay = 0;

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

    _setMonth(_currentMonth);
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

  void _setMonth(DateTime month) async {
    final records = await RecordStorage().getRecordsOfMonth(month);
    final monthlyBudget = await BudgetStorage().getMonthlyBudget(month);

    _backupRecords(_currentMonth, records);

    setState(() {
      _currentMonth = month;
      _records = records;
      _budgetIndexer = BudgetIndexer(monthlyBudget);

      final (calendar, startWeekday) = buildMonthCalendar(month.year, month.month);
      _dayCalendar = calendar;
      _startWeekDay = startWeekday;

      _recordCalendar = List.generate(6, (_) => List.generate(7, (_) => []));
      for (Record record in records) {
        final (i, j) = getCalendarIndex(record.dateTime.day);
        _recordCalendar[i][j].add(record);
      }

      if (_currentDayInitialized) {
        final lastDay = Utils.getLastDayInMonth(_currentMonth);
        if (_currentDay > lastDay) {
          _currentDay = 1;
        }
      } else {
        final now = DateTime.now();
        if (month.year == now.year && month.month == now.month) {
          _currentDay = now.day;
        } else {
          _currentDay = 1;
        }
        _currentDayInitialized = true;
      }
    });
  }

  void _updatePage() {
    _setMonth(_currentMonth);
  }

  (int, int) getCalendarIndex(int day) {
    int index = day + _startWeekDay - 1;
    int i = index ~/ 7;
    int j = index % 7;
    return (i, j);
  }

  (List<List<int>>, int) buildMonthCalendar(int year, int month) {
    // 6행 7열의 2차원 리스트를 0으로 초기화
    List<List<int>> calendar = List.generate(6, (_) => List.filled(7, 0));

    // 이번 달의 첫 날과 마지막 날짜 계산
    DateTime firstDay = DateTime(year, month, 1);
    int daysInMonth = Utils.getLastDayInMonth(firstDay);

    // 이번 달 1일의 요일 (0:일 ~ 6:토)
    int startWeekday = firstDay.weekday % 7; // DateTime에서 일요일은 7 → 0으로 맞춤

    int day = 1;
    for (int week = 0; week < 6; week++) {
      for (int weekday = 0; weekday < 7; weekday++) {
        // 첫 주의 시작 요일 전은 비워둠
        if (week == 0 && weekday < startWeekday) continue;
        if (day > daysInMonth) return (calendar, startWeekday);
        calendar[week][weekday] = day++;
      }
    }
    return (calendar, startWeekday);
  }

  void _backupRecords(DateTime month, List<Record> records) async {
    final recordStorage = RecordStorage();

    if (recordStorage.isDirty) {
      recordStorage.clearDirty();

      try {
        await BackupManager().uploadRecordsForMonth(_currentMonth, records);
      } catch (e) {
        if (mounted) {
          Utils.showPopup(context, '통신 실패', '서버와 통신하는 데에 실패했습니다.\n${e.toString()}}');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalIncome = 0;
    int totalExpense = 0;
    int totalDiff = 0;

    for (Record record in _records) {
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

    final labels = ['수입','지출','수지'];
    final values = [totalIncome, totalExpense, totalDiff];
    final days = ['일', '월', '화', '수', '목', '금', '토'];
    final weekCount = _dayCalendar[5][0] == 0 ? 5 : 6;

    final (i, j) = getCalendarIndex(_currentDay);
    final List<Record> records = _recordCalendar[i][j];

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
              Utils.getTableRowHeader(context, labels),
              Utils.getTableRowContent(context, values, useBlues: [false, false, true]),
            ],
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
              5: FlexColumnWidth(1),
              6: FlexColumnWidth(1),
            },
            border: TableBorder.all(
              color: Theme.of(context).colorScheme.surface,
              width: 1.0,
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
            children: [
              TableRow(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                children: List.generate(7, (col) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    child: Text(
                      days[col],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }),
              ),

              for (int i = 0; i < weekCount; ++i)
              TableRow(
                children: List.generate(7, (col) {
                  return CalendarDay(
                    day: _dayCalendar[i][col],
                    records: _recordCalendar[i][col],
                    selectedDay: _currentDay,
                    onTab: (day) {
                      setState(() {
                        _currentDay = day;
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).colorScheme.surfaceDim, width: 1),
              ),
            ),
          ),
          if (_budgetIndexer != null)
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(
                left: 0,
                right: 0,
                top: 0,
                bottom: 100,
              ),
              itemCount: records.length,
              itemBuilder: (context, index) {
                return RecordItem(
                  record: records[index],
                  budgetIndexer: _budgetIndexer!,
                  showDay: false,
                  onUpdated: () {
                    setState(() {
                      _updatePage();
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_budgetIndexer == null) {
            return;
          }

          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) {
                final now = DateTime.now();
                final initialDate = DateTime(
                  _currentMonth.year,
                  _currentMonth.month,
                  _currentDay,
                  now.hour,
                  now.minute,
                );
                return RecordEditPage(
                  initialDate: initialDate,
                  budgetIndexer: _budgetIndexer!,
                );
              },
            ),
          );

          if (changed == true) {
            _updatePage();
          }
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      )
    );
  }
}
