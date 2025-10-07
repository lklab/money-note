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
