import 'package:flutter/material.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../services/prefs_service.dart';
import '../models/account.dart';
import 'account_form_screen.dart';
import '../widgets/date_range_app_bar.dart';

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key});

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
      Future<void> _populateDefaultAccounts() async {
        // Contas padrão para exemplo/teste
        final defaultAccounts = [
          Account(
            description: 'Supermercado',
            value: 150.00,
            dueDay: 5,
            month: _startDate.month,
            year: _startDate.year,
            typeId: 1,
            observation: 'Cartão Crédito',
            isRecurrent: false,
          ),
          // ...demais contas padrão...
        ];
        int addedCount = 0;
        for (final account in defaultAccounts) {
          try {
            await DatabaseHelper.instance.createAccount(account);
            addedCount++;
          } catch (e) {} // ignore: empty_catches
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                addedCount > 0
                    ? '$addedCount lançamentos adicionados com sucesso!'
                    : 'Não foi possível adicionar os lançamentos.',
              ),
              backgroundColor: addedCount > 0 ? Colors.green : Colors.orange,
            ),
          );
        }
        _loadData();
      }
    Widget _buildAccountCard(Account acc) {
      bool isRecurrent = acc.isRecurrent;
      String dayStr = acc.dueDay.toString().padLeft(2, '0');
      final borderRadius = BorderRadius.circular(12);
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => _showEditDialog(acc),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isRecurrent ? Colors.grey.shade200 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayStr,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87
                        ),
                      ),
                      Text(
                        isRecurrent ? 'Prev.' : 'Dia',
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.description,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(
                              _typeNames[acc.typeId] ?? 'Outros',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                          if(isRecurrent)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.loop, size: 14, color: Colors.grey),
                            )
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      UtilBrasilFields.obterReal(acc.value),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isRecurrent ? Colors.grey : Colors.green.shade700
                      ),
                    ),
                    if (!isRecurrent && acc.id != null && _paymentInfo.containsKey(acc.id))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '*** PAGO ***',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              'via ${_paymentInfo[acc.id!]?['method_name'] ?? ''}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _showEditDialog(acc),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: Icon(Icons.edit, size: 20, color: Colors.blue.shade800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _confirmDelete(acc),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: Icon(Icons.delete, size: 20, color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      );
    }

    Future<void> _showEditDialog(Account account) async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AccountFormScreen(accountToEdit: account),
        ),
      );
      if (result == true) {
        _loadData();
      }
    }

    Future<void> _confirmDelete(Account acc) async {
      // ...mantenha a implementação existente...
    }
  // Todas as funções auxiliares já estão corretamente declaradas como métodos da classe.
  // Removido qualquer função local duplicada.
    late DateTime _startDate;
  late DateTime _endDate;
  bool _datesInitialized = false;
  late final VoidCallback _dateRangeListener;

  List<Account> _accounts = [];
  Map<int, String> _typeNames = {};
  bool _isLoading = true;
  double _totalMonth = 0.0; // Variável para o total
  Map<int, Map<String, dynamic>> _paymentInfo = {};

  @override
  void dispose() {
    PrefsService.dateRangeNotifier.removeListener(_dateRangeListener);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dateRangeListener = () {
      final range = PrefsService.dateRangeNotifier.value;
      setState(() {
        _startDate = DateTime(range.start.year, range.start.month, 1);
        _endDate = DateTime(range.start.year, range.start.month + 1, 0);
        _datesInitialized = true;
      });
      _loadData();
    };
    PrefsService.dateRangeNotifier.addListener(_dateRangeListener);
    _initDates();
  }

  Future<void> _initDates() async {
    final range = PrefsService.dateRangeNotifier.value;
    setState(() {
      _startDate = DateTime(range.start.year, range.start.month, 1);
      _endDate = DateTime(range.start.year, range.start.month + 1, 0);
      _datesInitialized = true;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final rawAccounts = await DatabaseHelper.instance.readAccountsByDate(_startDate.month, _startDate.year);
    final types = await DatabaseHelper.instance.readAllTypes();
    final typeMap = {for (var t in types) t.id!: t.name};

    // --- FILTRAGEM INTELIGENTE (Esconde Recorrentes se houver Específica) ---
    List<Account> filteredList = [];
    Set<int> typesWithSpecifics = {};

    for (var acc in rawAccounts) {
      if (!acc.isRecurrent) {
        typesWithSpecifics.add(acc.typeId);
      }
    }

    for (var acc in rawAccounts) {
      if (acc.isRecurrent) {
        if (typesWithSpecifics.contains(acc.typeId)) continue;
      }
      filteredList.add(acc);
    }
    
    // ORDENAÇÃO POR DIA (Garantia)
    filteredList.sort((a, b) => a.dueDay.compareTo(b.dueDay));

    // CÁLCULO DO TOTAL
    double total = filteredList.fold(0, (sum, item) => sum + item.value);

    // Carregar informações de pagamento em paralelo
    final paymentInfo = <int, Map<String, dynamic>>{};

    final accountsToLoad = filteredList
        .where((account) => account.cardBrand == null && account.id != null)
        .map((account) => account.id!)
        .toList();

    if (accountsToLoad.isNotEmpty) {
      final paymentQueries = accountsToLoad.map((accountId) async {
        final info = await DatabaseHelper.instance.getAccountPaymentInfo(accountId);
        if (info != null) {
          paymentInfo[accountId] = info;
        }
      }).toList();

      await Future.wait(paymentQueries);
    }

    setState(() {
      _accounts = filteredList;
      _typeNames = typeMap;
      _totalMonth = total;
      _paymentInfo = paymentInfo;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_datesInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? Colors.grey.shade900 : Colors.blue.shade50;
    final totalColor = isDark ? Colors.greenAccent : Colors.blue.shade900;
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 640 || media.size.width < 360;
    final headerPadding = isCompact ? 10.0 : 16.0;
    final totalFontSize = isCompact ? 20.0 : 24.0;
    final totalLabelFontSize = isCompact ? 12.0 : 14.0;

    return Scaffold(
      appBar: DateRangeAppBar(
        title: 'Gerenciar Lançamentos',
        range: DateTimeRange(start: _startDate, end: _endDate),
        onPrevious: () => PrefsService.shiftDateRange(-1),
        onNext: () => PrefsService.shiftDateRange(1),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Popular com padrões',
            onPressed: _populateDefaultAccounts,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(headerPadding),
              color: headerColor,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12 : 16,
                      vertical: isCompact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'TOTAL DO MÊS: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: totalLabelFontSize,
                            ),
                          ),
                          Text(
                            UtilBrasilFields.obterReal(_totalMonth),
                            style: TextStyle(
                              fontSize: totalFontSize,
                              fontWeight: FontWeight.bold,
                              color: totalColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _accounts.isEmpty
                      ? const Center(
                          child: Text('Nenhum lançamento encontrado.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _accounts.length,
                          itemBuilder: (context, index) {
                            final acc = _accounts[index];
                            return _buildAccountCard(acc);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }


}
// ignore_for_file: deprecated_member_use
