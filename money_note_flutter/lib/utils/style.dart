import 'package:flutter/material.dart';

class Style {
  static final ButtonStyle buttonStyle = ButtonStyle(
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    )
  );

  static final InputDecoration inputDecoration = InputDecoration(
    isDense: true,
    border: UnderlineInputBorder(),
    enabledBorder: UnderlineInputBorder(),
    focusedBorder: UnderlineInputBorder(),
  );

  static final Color positiveColor = Color(0xFF007AFF);
  static final Color negativeColor = Color(0xFFFF3B30);
  static final Color neutralColor = Color(0xFF1C1B1F);

  static InputDecoration getSingleLineInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      isDense: true,
      border: UnderlineInputBorder(),
      enabledBorder: UnderlineInputBorder(),
      focusedBorder: UnderlineInputBorder(),
    );
  }

  static InputDecoration getMultiLineInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      alignLabelWithHint: true,
      border: UnderlineInputBorder(),
      enabledBorder: UnderlineInputBorder(),
      focusedBorder: UnderlineInputBorder(),
    );
  }
}
