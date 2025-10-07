import 'package:flutter/material.dart';
import 'package:money_note_flutter/utils/style.dart';

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
    return v >= 0 ? (useBlue ? Color(0xFF007AFF) : Color(0xFF1C1B1F)) : Color(0xFFFF3B30);
  }

  static void showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
}
