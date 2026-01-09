import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/account_type.dart';
import '../models/account_category.dart';
import '../models/payment_method.dart';
import '../models/bank_account.dart';
import '../models/payment.dart';

class DataExplorerScreen extends StatefulWidget {
  const DataExplorerScreen({super.key});

  @override
  State<DataExplorerScreen> createState() => _DataExplorerScreenState();
}

class _DataExplorerScreenState extends State<DataExplorerScreen> {
  String _selectedTable = 'Contas';
  final List<String> _tables = [
    'Contas',
    'Tipos',
    'Categorias',
    'Pagamentos',
    'Bancos',
    'Formas de Pagamento/Recebimento'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorador de Dados'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Abas de Tabelas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: _tables.map((table) {
                  final isSelected = _selectedTable == table;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(table),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedTable = table);
                      },
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: Colors.blue.shade400,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(thickness: 1),
          // Conteúdo da Tabela
          Expanded(
            child: _buildTableContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTableContent() {
    switch (_selectedTable) {
      case 'Contas':
        return _buildAccountsTable();
      case 'Tipos':
        return _buildTypesTable();
      case 'Categorias':
        return _buildCategoriesTable();
      case 'Pagamentos':
        return _buildPaymentsTable();
      case 'Bancos':
        return _buildBanksTable();
      case 'Formas de Pagamento/Recebimento':
        return _buildPaymentMethodsTable();
      default:
        return const Center(child: Text('Tabela não encontrada'));
    }
  }

  Widget _buildAccountsTable() {
    return FutureBuilder<List<Account>>(
      future: DatabaseHelper.instance.readAllAccountsRaw(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhuma conta encontrada'));
        }

        final accounts = snapshot.data!;
        return ListView.builder(
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            final date = account.month != null && account.year != null
                ? '${account.dueDay}/${account.month}/${account.year}'
                : '-';
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(account.description),
                subtitle: Text('R\$ ${account.value.toStringAsFixed(2)} | $date'),
                trailing: Text('#${account.id}'),
                onTap: () => _showDetailsDialog(context, 'Conta', account),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypesTable() {
    return FutureBuilder<List<AccountType>>(
      future: DatabaseHelper.instance.readAllTypes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhum tipo encontrado'));
        }

        final types = snapshot.data!;
        return ListView.builder(
          itemCount: types.length,
          itemBuilder: (context, index) {
            final type = types[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(type.name),
                trailing: Text('#${type.id}'),
                onTap: () => _showDetailsDialog(context, 'Tipo', type),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoriesTable() {
    return FutureBuilder<List<AccountCategory>>(
      future: DatabaseHelper.instance.readAllAccountCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhuma categoria encontrada'));
        }

        final categories = snapshot.data!;
        return ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(cat.categoria),
                subtitle: Text('Tipo ID: ${cat.accountId}'),
                trailing: Text('#${cat.id}'),
                onTap: () => _showDetailsDialog(context, 'Categoria', cat),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentsTable() {
    return FutureBuilder<List<Payment>>(
      future: DatabaseHelper.instance.readAllPayments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhum pagamento encontrado'));
        }

        final payments = snapshot.data!;
        return ListView.builder(
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text('Conta #${payment.accountId}'),
                subtitle: Text('R\$ ${payment.value.toStringAsFixed(2)} | ${payment.paymentDate}'),
                trailing: Text('#${payment.id}'),
                onTap: () => _showDetailsDialog(context, 'Pagamento', payment),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBanksTable() {
    return FutureBuilder<List<BankAccount>>(
      future: DatabaseHelper.instance.readBankAccounts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhum banco encontrado'));
        }

        final banks = snapshot.data!;
        return ListView.builder(
          itemCount: banks.length,
          itemBuilder: (context, index) {
            final bank = banks[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(bank.name),
                subtitle: Text('${bank.agency} / ${bank.account}'),
                trailing: Text('#${bank.id}'),
                onTap: () => _showDetailsDialog(context, 'Banco', bank),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentMethodsTable() {
    return FutureBuilder<List<PaymentMethod>>(
      future: DatabaseHelper.instance.readPaymentMethods(onlyActive: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhuma forma de pagamento encontrada'));
        }

        final methods = snapshot.data!;
        return ListView.builder(
          itemCount: methods.length,
          itemBuilder: (context, index) {
            final method = methods[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(method.name),
                subtitle: Text('Ativo: ${method.isActive ? "Sim" : "Não"}'),
                trailing: Text('#${method.id}'),
                onTap: () =>
                    _showDetailsDialog(context, 'Forma de Pagamento/Recebimento', method),
              ),
            );
          },
        );
      },
    );
  }

  void _showDetailsDialog(BuildContext context, String type, dynamic object) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detalhes - $type',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildDetailsList(object),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsList(dynamic object) {
    if (object is Account) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('ID', '${object.id}'),
          _detailRow('Descrição', object.description),
          _detailRow('Valor', 'R\$ ${object.value.toStringAsFixed(2)}'),
          _detailRow('Data', '${object.dueDay}/${object.month}/${object.year}'),
          _detailRow('Tipo ID', '${object.typeId}'),
          _detailRow('Recorrente', object.isRecurrent ? 'Sim' : 'Não'),
          _detailRow('Pagar Antecipado', object.payInAdvance ? 'Sim' : 'Não'),
          _detailRow('Observação', object.observation ?? '-'),
        ],
      );
    } else if (object is AccountType) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('ID', '${object.id}'),
          _detailRow('Nome', object.name),
        ],
      );
    } else if (object is AccountCategory) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('ID', '${object.id}'),
          _detailRow('Categoria', object.categoria),
          _detailRow('Tipo ID', '${object.accountId}'),
        ],
      );
    } else if (object is Payment) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('ID', '${object.id}'),
          _detailRow('Conta ID', '${object.accountId}'),
          _detailRow('Valor', 'R\$ ${object.value.toStringAsFixed(2)}'),
          _detailRow('Data Pagamento', object.paymentDate),
          _detailRow('Método ID', '${object.paymentMethodId}'),
          _detailRow('Observação', object.observation ?? '-'),
        ],
      );
    } else if (object is BankAccount) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('ID', '${object.id}'),
          _detailRow('Nome', object.name),
          _detailRow('Código', '${object.code}'),
          _detailRow('Agência', object.agency),
          _detailRow('Conta', object.account),
          _detailRow('Descrição', object.description),
        ],
      );
    } else if (object is PaymentMethod) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('ID', '${object.id}'),
          _detailRow('Nome', object.name),
          _detailRow('Tipo', object.type),
          _detailRow('Ativo', object.isActive ? 'Sim' : 'Não'),
          _detailRow('Requer Banco', object.requiresBank ? 'Sim' : 'Não'),
        ],
      );
    }
    return const Text('Tipo desconhecido');
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
