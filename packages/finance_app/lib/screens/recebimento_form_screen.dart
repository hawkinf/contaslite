import 'package:flutter/material.dart';
import 'account_form_screen.dart';

class RecebimentoFormScreen extends StatelessWidget {
  const RecebimentoFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      insetPadding: EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxWidth: 600,
        maxHeight: 800,
      ),
      child: AccountFormScreen(
        typeNameFilter: 'Recebimentos',
        lockTypeSelection: true,
        useInstallmentDropdown: true,
        isRecebimento: true,
      ),
    );
  }
}
