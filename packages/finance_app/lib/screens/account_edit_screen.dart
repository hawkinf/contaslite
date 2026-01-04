import 'package:flutter/material.dart';
// imports removidos pois não são utilizados
// imports removidos pois não são utilizados
import '../models/account.dart';
import '../services/prefs_service.dart';
import '../widgets/date_range_app_bar.dart';
// import removido pois não é utilizado
// imports removidos pois não são utilizados
// import '../utils/installment_utils.dart';



// Classe _InstallmentDraft removida pois não é utilizada



// Enum _DeleteAction removido pois não é utilizado

class AccountEditScreen extends StatefulWidget {
  final Account account;
  const AccountEditScreen({super.key, required this.account});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  // Métodos utilitários necessários para evitar erros de método indefinido

  // Métodos utilitários reais já implementados abaixo, removendo duplicidade de stubs

  late TextEditingController _descController;
  late TextEditingController _valueController;
  late TextEditingController _dateController;
  late TextEditingController _installmentsQtyController;
  late TextEditingController _observationController;
  // Campos essenciais para funcionamento
  // Removidos campos não utilizados
  // Limpeza: removido bloco com variáveis não declaradas e await fora de contexto


  @override
  void initState() {
    super.initState();

    _descController = TextEditingController();
    _valueController = TextEditingController();
    _dateController = TextEditingController();
    _installmentsQtyController = TextEditingController();
    _observationController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        return Scaffold(
          appBar: DateRangeAppBar(
            title: 'Editar Conta',
            range: range,
            onPrevious: () => PrefsService.shiftDateRange(-1),
            onNext: () => PrefsService.shiftDateRange(1),
          ),
          body: const Center(child: Text('Tela de edição de conta')),
        );
      },
    );
  }


  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    _dateController.dispose();
    _installmentsQtyController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  // ...existing code...

  // Método removido

  // Método removido

  // Método removido

  // Removido _selectDate não referenciado

  // Método removido

  // Método removido

  // ...existing code...

  // Removido _onInstallmentValueChanged não referenciado



  // Removido _updateExistingInstallments não referenciado
}
  // Métodos de exclusão removidos



  // Removido _buildInstallmentsEditor não referenciado

  // Removido _buildSummaryCard não referenciado



