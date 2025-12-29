import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/payment_method.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';

class PayAccountScreen extends StatefulWidget {
  final Account account;

  const PayAccountScreen({super.key, required this.account});

  @override
  State<PayAccountScreen> createState() => _PayAccountScreenState();
}

class _PayAccountScreenState extends State<PayAccountScreen> {
  late Future<List<PaymentMethod>> _paymentMethodsFuture;

  @override
  void initState() {
    super.initState();
    _paymentMethodsFuture =
        DatabaseHelper.instance.readPaymentMethods(onlyActive: true);
  }

  Future<void> _onPaymentMethodSelected(PaymentMethod method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Pagamento'),
        content: Text(
          'Deseja registrar o pagamento de "${widget.account.description}" com "${method.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final now = DateTime.now();
      final payment = Payment(
        accountId: widget.account.id!,
        paymentMethodId: method.id!,
        paymentDate: now.toIso8601String(),
        value: widget.account.value,
        createdAt: now.toIso8601String(),
      );
      await DatabaseHelper.instance.createPayment(payment);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Pagamento'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildAccountSummaryCard(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Selecione a forma de pagamento:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<PaymentMethod>>(
                future: _paymentMethodsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('Nenhuma forma de pagamento encontrada.'));
                  }

                  final methods = snapshot.data!;
                  return ListView.builder(
                    itemCount: methods.length,
                    itemBuilder: (context, index) {
                      final method = methods[index];
                      return ListTile(
                        leading: Icon(method.icon),
                        title: Text(method.name),
                        onTap: () => _onPaymentMethodSelected(method),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSummaryCard() {
    final currencyFormat =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final year = widget.account.year ?? DateTime.now().year;
    final month = widget.account.month ?? DateTime.now().month;
    final baseDay = widget.account.dueDay;
    final originalDueDate = DateTime(year, month, baseDay);
    final isWeekend = HolidayService.isWeekend(originalDueDate);
    final isHoliday = HolidayService.isHoliday(originalDueDate, PrefsService.cityNotifier.value);
    final isAdjusted = isWeekend || isHoliday;

    DateTime adjustedDueDate = originalDueDate;
    if (isAdjusted) {
      if (widget.account.payInAdvance) {
        while (HolidayService.isWeekend(adjustedDueDate) ||
            HolidayService.isHoliday(adjustedDueDate, PrefsService.cityNotifier.value)) {
          adjustedDueDate = adjustedDueDate.subtract(const Duration(days: 1));
        }
      } else {
        while (HolidayService.isWeekend(adjustedDueDate) ||
            HolidayService.isHoliday(adjustedDueDate, PrefsService.cityNotifier.value)) {
          adjustedDueDate = adjustedDueDate.add(const Duration(days: 1));
        }
      }
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.account.description,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Valor:'),
                Text(
                  currencyFormat.format(widget.account.value),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Vencimento:'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Original: ${DateFormat('dd/MM/yyyy').format(originalDueDate)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (isAdjusted)
                      Text(
                        'Ajustada: ${DateFormat('dd/MM/yyyy').format(adjustedDueDate)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
