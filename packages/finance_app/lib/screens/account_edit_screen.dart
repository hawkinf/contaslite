import 'package:flutter/material.dart';
import '../models/account.dart';
import '../database/db_helper.dart';
import 'account_form_screen.dart';

class AccountEditScreen extends StatefulWidget {
  final Account account;

  const AccountEditScreen({super.key, required this.account});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  late Future<bool> _isRecebimentoFuture;

  @override
  void initState() {
    super.initState();
    _isRecebimentoFuture = _checkIfRecebimento();
  }

  Future<bool> _checkIfRecebimento() async {
    try {
      final types = await DatabaseHelper.instance.readAllTypes();
      final typeId = widget.account.typeId;
      final type = types.firstWhere((t) => t.id == typeId, orElse: () => throw Exception('Type not found'));
      return type.name.trim().toLowerCase() == 'recebimentos';
    } catch (e) {
      debugPrint('Erro ao verificar tipo: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isRecebimentoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isRecebimento = snapshot.data ?? false;
        return AccountFormScreen(
          accountToEdit: widget.account,
          isRecebimento: isRecebimento,
        );
      },
    );
  }
}
