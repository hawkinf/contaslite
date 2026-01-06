import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/payment_method.dart';
import '../widgets/app_input_decoration.dart';
import '../services/prefs_service.dart';
import '../widgets/date_range_app_bar.dart';
import '../widgets/dialog_close_button.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  late Future<List<PaymentMethod>> _futurePaymentMethods;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  void _loadPaymentMethods() {
    _futurePaymentMethods = DatabaseHelper.instance.readPaymentMethods(onlyActive: false);
  }

  void _refresh() {
    setState(() {
      _loadPaymentMethods();
    });
  }

  void _showPaymentMethodDialog({PaymentMethod? method}) {
    showDialog(
      context: context,
      builder: (context) {
        final isEditing = method != null;
        final nameController = TextEditingController(text: method?.name ?? '');
        final typeController = TextEditingController(text: method?.type ?? '');

        // Se é novo e nome está vazio, usar o tipo como padrão
        if (!isEditing && nameController.text.isEmpty && typeController.text.isNotEmpty) {
          nameController.text = typeController.text;
        }

        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Editar Forma de Pagamento' : 'Nova Forma de Pagamento',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: nameController,
                          decoration: buildOutlinedInputDecoration(
                            label: 'Nome',
                            icon: Icons.payment,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: typeController,
                          onChanged: (value) {
                            // Se o nome está vazio, preencher com o tipo
                            if (nameController.text.isEmpty && value.isNotEmpty) {
                              nameController.text = value;
                            }
                          },
                          decoration: buildOutlinedInputDecoration(
                            label: 'Tipo (ex: CASH, PIX, BANK_DEBIT)',
                            icon: Icons.category,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final type = typeController.text.trim();

                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Nome é obrigatório')),
                                  );
                                  return;
                                }

                                if (type.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tipo é obrigatório')),
                                  );
                                  return;
                                }

                                // Verificar duplicidade
                                final exists = await DatabaseHelper.instance
                                    .checkPaymentMethodExists(name, excludeId: method?.id);
                                if (!context.mounted) return;

                                if (exists) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Já existe uma forma de pagamento com este nome')),
                                  );
                                  return;
                                }

                                // Salvar
                                if (isEditing) {
                                  await DatabaseHelper.instance.updatePaymentMethod(
                                    method.copyWith(
                                      name: name,
                                      type: type,
                                    ),
                                  );
                                } else {
                                  await DatabaseHelper.instance.createPaymentMethod(
                                    PaymentMethod(
                                      name: name,
                                      type: type,
                                      iconCode: 0xe25a, // Ícone padrão
                                      requiresBank: false,
                                      isActive: true,
                                    ),
                                  );
                                }

                                if (!context.mounted) return;
                                Navigator.pop(context);
                                _refresh();
                              },
                              child: Text(isEditing ? 'Salvar' : 'Criar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DialogCloseButton(
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _deletePaymentMethod(PaymentMethod method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Forma de Pagamento?'),
        content: Text('Tem certeza que deseja deletar "${method.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deletePaymentMethod(method.id!);
              if (!context.mounted) return;
              Navigator.pop(context);
              _refresh();
            },
            child: const Text('Deletar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        return Scaffold(
      appBar: DateRangeAppBar(
          title: 'Formas de Pagamento',
          range: range,
          onPrevious: () => PrefsService.shiftDateRange(-1),
          onNext: () => PrefsService.shiftDateRange(1),
        ),
        floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentMethodDialog(),
        label: const Text('Novo Item'),
        icon: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<PaymentMethod>>(
        future: _futurePaymentMethods,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Erro: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Nenhuma forma de pagamento cadastrada'),
            );
          }

          final methods = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: methods.length,
            itemBuilder: (context, index) {
              final method = methods[index];
              final statusColor = method.isActive
                  ? Colors.green
                  : Colors.red;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 60,
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                method.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            method.isActive ? 'Ativo' : 'Inativo',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Tooltip(
                              message: 'Editar',
                              child: IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () =>
                                    _showPaymentMethodDialog(method: method),
                                iconSize: 24,
                              ),
                            ),
                            Tooltip(
                              message: 'Deletar',
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deletePaymentMethod(method),
                                iconSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
        );
      },
    );
  }
}
