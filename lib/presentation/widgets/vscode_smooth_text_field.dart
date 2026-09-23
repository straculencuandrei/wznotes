import 'package:flutter/material.dart';

/// Clean, hardware-accelerated text field with unified cursor and handle alignment.
/// Eliminates any caret drift or distortion across note screen limits and text wrapping.
class VSCodeSmoothTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final String hintText;
  final TextStyle hintStyle;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const VSCodeSmoothTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.hintText,
    required this.hintStyle,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines,
    this.keyboardType = TextInputType.multiline,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      showCursor: true,
      cursorColor: const Color(0xFFFF9100), // Clean Warm Amber / Samsung Orange
      cursorWidth: 2.4,
      cursorRadius: const Radius.circular(1.5),
      cursorOpacityAnimates: true,
      style: style,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hintText,
        hintStyle: hintStyle,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: onChanged,
    );
  }
}
