import 'package:flutter/material.dart';
import 'account_form_screen.dart';

class RecebimentoFormScreen extends StatelessWidget {
  const RecebimentoFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AccountFormScreen(
      typeNameFilter: 'Recebimentos',
      lockTypeSelection: true,
      useInstallmentDropdown: true,
      isRecebimento: true,
    );
  }
}
