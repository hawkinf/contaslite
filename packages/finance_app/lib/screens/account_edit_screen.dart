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
  late Future<String?> _typeNameFuture;

  @override
  void initState() {
    super.initState();
    _typeNameFuture = _getTypeName();
  }

  Future<String?> _getTypeName() async {
    try {
      final types = await DatabaseHelper.instance.readAllTypes();
      final typeId = widget.account.typeId;
      final type = types.firstWhere((t) => t.id == typeId, orElse: () => throw Exception('Type not found'));
      return type.name;
    } catch (e) {
      debugPrint('Erro ao obter tipo de conta: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _typeNameFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final typeName = snapshot.data;
        return AccountFormScreen(
          accountToEdit: widget.account,
          typeNameFilter: typeName,
          lockTypeSelection: true,
        );
      },
    );
  }
}
