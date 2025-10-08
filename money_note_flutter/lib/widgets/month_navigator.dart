import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthNavigator extends StatefulWidget {
  final DateTime initialValue;
  final Function(DateTime) onChange;

  const MonthNavigator({
    super.key,
    required this.initialValue,
    required this.onChange,
  });

  @override
  State<MonthNavigator> createState() => _MonthNavigatorState();
}

class _MonthNavigatorState extends State<MonthNavigator> {
  late DateTime current;

  @override
  void initState() {
    super.initState();
    current = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              current = DateTime(current.year, current.month - 1, current.day);
              widget.onChange(current);
            });
          },
          icon: Icon(Icons.navigate_before),
        ),
        Expanded(
          child: Text(
            DateFormat('yyyy.MM').format(current),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              current = DateTime(current.year, current.month + 1, current.day);
              widget.onChange(current);
            });
          },
          icon: Icon(Icons.navigate_next),
        ),
      ],
    );
  }
}
