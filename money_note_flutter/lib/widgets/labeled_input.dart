import 'package:flutter/material.dart';

class LabeledInput extends StatelessWidget {
  final String label;
  final Widget child;
  final CrossAxisAlignment crossAxisAlignment;

  const LabeledInput({
    super.key,
    required this.label,
    required this.child,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: child,
        ),
      ],
    );
  }
}
