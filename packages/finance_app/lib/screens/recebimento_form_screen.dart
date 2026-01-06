import 'package:flutter/material.dart';
import 'account_form_screen.dart';

class RecebimentoFormScreen extends StatelessWidget {
  const RecebimentoFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;

    // Calcular dimensões responsivas
    final maxWidth = (screenSize.width * 0.9).clamp(280.0, 600.0);
    final availableHeight = screenSize.height - viewInsets.bottom;
    final maxHeight = (availableHeight * 0.85).clamp(400.0, 900.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      child: const AccountFormScreen(
        typeNameFilter: 'Recebimentos',
        lockTypeSelection: true,
        useInstallmentDropdown: true,
        isRecebimento: true,
      ),
    );
  }
}
