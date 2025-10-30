import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:money_note/utils/style.dart';

class Utils {
  static String formatMoney(int v) {
    bool isNegative = v < 0;

    if (isNegative) {
      v = -v;
    }

    final s = v.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write(',');
        count = 0;
      }
    }

    if (isNegative) {
      buf.write('-');
    }

    return buf.toString().split('').reversed.join();
  }

  static Color getMoneyColor(int v, {bool useBlue = false}) {
    return v == 0 ? Style.neutralColor : v > 0 ? (useBlue ? Style.positiveColor : Style.neutralColor) : Style.negativeColor;
  }

  static void showSnack(BuildContext context, String msg, {Duration duration = const Duration(milliseconds: 300)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: duration,
    ));
  }

  static Future<bool?> confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제하시겠어요?'),
        content: const Text('이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: Style.buttonStyle,
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: Style.buttonStyle,
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  static void showPopup(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: Style.buttonStyle,
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showConfirmPopup(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: Style.buttonStyle,
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: Style.buttonStyle,
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  static Future<DateTime?> pickDateTime(
    BuildContext context, {
    DateTime? initial,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();

    final DateTime init = initial ?? now;
    final DateTime first = firstDate ?? DateTime(1970, 1, 1);
    final DateTime last  = lastDate  ?? DateTime(2100, 12, 31);

    // 1) 날짜 고르기
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: first,
      lastDate: last,
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '다음',
      builder: (context, child) {
        // 다크모드/테마 커스터마이징 하고 싶으면 여기서 child 감싸기
        return child!;
      },
    );

    if (pickedDate == null) return null; // 사용자가 취소

    // 2) 시간 고르기 (시/분)
    final TimeOfDay? pickedTime = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: TimeOfDay(hour: init.hour, minute: init.minute),
      helpText: '시간 선택',
      cancelText: '취소',
      confirmText: '확인',
      // 키보드 입력 모드로 시작하려면 다음 줄 주석 해제:
      // initialEntryMode: TimePickerEntryMode.input,
    );

    if (pickedTime == null) return null; // 사용자가 취소

    // 3) 날짜 + 시간 합치기 (초/밀리초는 0으로)
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  static Future<DateTime?> showCupertinoDateTimePicker(
    BuildContext context, {
    DateTime? initial,
    DateTime? minDate,
    DateTime? maxDate,
  }) async {
    DateTime temp = initial ?? DateTime.now();

    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 액션 바
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(child: const Text('취소'), onPressed: () => Navigator.pop(context)),
                  const Text('날짜/시간 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(child: const Text('완료'), onPressed: () => Navigator.pop(context, temp)),
                ],
              ),
              SizedBox(
                height: 216,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: temp,
                  minimumDate: minDate,
                  maximumDate: maxDate,
                  minuteInterval: 1, // 시/분까지만 (초 없음)
                  use24hFormat: true, // 24시간제
                  onDateTimeChanged: (v) => temp = v,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static int getLastDayInMonth(DateTime date) {
    DateTime nextMonth = (date.month == 12)
        ? DateTime(date.year + 1, 1, 1)
        : DateTime(date.year, date.month + 1, 1);
    return nextMonth.subtract(const Duration(days: 1)).day;
  }

  static TableRow getTableRowHeader(BuildContext context, List<String> texts) {
    return TableRow(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
      children: List.generate(texts.length, (col) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              texts[col],
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      }),
    );
  }

  static TableRow getTableRowContent(BuildContext context, List<int> values, {List<bool>? useBlues}) {
    useBlues ??= List.filled(values.length, false);

    if (values.length > useBlues.length) {
      useBlues += List.filled(values.length - useBlues.length, false);
    }

    return TableRow(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer),
      children: List.generate(values.length, (col) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Utils.formatMoney(values[col]),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Utils.getMoneyColor(values[col], useBlue: useBlues![col]),
              ),
            ),
          ),
        );
      }),
    );
  }
}
