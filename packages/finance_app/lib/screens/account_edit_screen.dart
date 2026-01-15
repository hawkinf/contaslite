import 'package:flutter/material.dart';
import '../models/account.dart';
import '../database/db_helper.dart';
import 'account_form_screen.dart';

class AccountEditScreen extends StatefulWidget {
  final Account account;
  final VoidCallback? onClose;

  const AccountEditScreen({super.key, required this.account, this.onClose});

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
    debugPrint('🧭 AccountEditScreen.build chamado');
    return FutureBuilder<bool>(
      future: _isRecebimentoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('🧭 AccountEditScreen aguardando _isRecebimentoFuture...');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isRecebimento = snapshot.data ?? false;
        debugPrint('🧭 AccountEditScreen pronto. isRecebimento=$isRecebimento');
        // AccountFormScreen agora tem seu próprio Scaffold com AppBar e bottomNavigationBar
        return AccountFormScreen(
          accountToEdit: widget.account,
          isRecebimento: isRecebimento,
          onClose: widget.onClose,
        );
      },
    );
  }
}
