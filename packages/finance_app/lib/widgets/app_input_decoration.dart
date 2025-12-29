import 'package:flutter/material.dart';

/// Padrão único para campos: outlined, label flutuante e ícone inicial.
InputDecoration buildOutlinedInputDecoration({
  required String label,
  required IconData icon,
  String? hintText,
  String? prefixText,
  TextStyle? prefixStyle,
  Widget? suffixIcon,
  bool dense = false,
  EdgeInsetsGeometry? contentPadding,
  bool alignLabelWithHint = false,
}) {
  final baseBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade400),
  );

  return InputDecoration(
    labelText: label,
    hintText: hintText,
    prefixIcon: Icon(icon),
    prefixText: prefixText,
    prefixStyle: prefixStyle,
    suffixIcon: suffixIcon,
    isDense: dense,
    alignLabelWithHint: alignLabelWithHint,
    contentPadding: contentPadding ??
        EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 12 : 16),
    border: baseBorder,
    enabledBorder: baseBorder,
    focusedBorder: baseBorder.copyWith(
      borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
    ),
  );
}
