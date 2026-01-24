import 'package:flutter/material.dart';
import 'account_form_screen.dart';
import '../ui/components/standard_modal_shell.dart';

class RecebimentoFormScreen extends StatelessWidget {
  const RecebimentoFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;
    // Calcular dimensões responsivas - padrão novo
    final maxWidth = (screenSize.width * 0.92).clamp(320.0, 820.0);
    final availableHeight = screenSize.height - viewInsets.bottom;
    final maxHeight = (availableHeight * 0.88).clamp(420.0, 780.0);
    return StandardModalShell(
      title: 'Novo Recebimento',
      onClose: () => Navigator.pop(context),
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      scrollBody: false,
      bodyPadding: EdgeInsets.zero,
      body: const AccountFormScreen(
        typeNameFilter: 'Recebimentos',
        lockTypeSelection: true,
        isRecebimento: true,
        showAppBar: false,
      ),
    );
  }
}
