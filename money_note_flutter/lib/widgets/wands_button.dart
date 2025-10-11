import 'package:flutter/material.dart';
import 'package:money_note/utils/style.dart';

class WandsButton extends StatelessWidget {
  final bool isFilled;
  final String text;
  final Function()? onPressed;

  const WandsButton({
    super.key,
    this.onPressed,
    this.isFilled = true,
    this.text = '',
  });

  @override
  Widget build(BuildContext context) {
    if (isFilled) {
      return FilledButton(
        onPressed: onPressed,
        style: Style.buttonStyle,
        child: Text(text),
      );
    } else {
      return OutlinedButton(
        onPressed: onPressed,
        style: Style.buttonStyle,
        child: Text(text),
    );
    }
  }
}
