import 'package:flutter/material.dart';
import '../models/account.dart';
import 'account_form_screen.dart';

class AccountEditScreen extends StatelessWidget {
  final Account account;

  const AccountEditScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    // Redirecionar para AccountFormScreen em modo de edição
    return AccountFormScreen(accountToEdit: account);
  }
}
