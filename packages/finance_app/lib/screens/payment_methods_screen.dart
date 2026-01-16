
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/payment_method.dart';
import '../services/database_initialization_service.dart';
import '../services/default_account_categories_service.dart';
import '../widgets/app_input_decoration.dart';
import '../services/prefs_service.dart';
import '../widgets/dialog_close_button.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  late Future<List<PaymentMethod>> _futurePaymentMethods;
  bool _isPopulating = false;

  static const int _fallbackIconCode = 0xe25a; // payments
  static const List<IconData> _iconPalette = [
    Icons.credit_card,
    Icons.account_balance_wallet,
    Icons.attach_money,
    Icons.payments,
    Icons.pix,
    Icons.qr_code,
    Icons.account_balance,
    Icons.receipt_long,
    Icons.wallet,
    Icons.shopping_bag,
    Icons.money_outlined,
  ];

  IconData _inferIcon(String name, String type) {
    final text = '${name.toLowerCase()} ${type.toLowerCase()}';
    if (text.contains('credito') || text.contains('crédito') || text.contains('credit')) {
      return Icons.credit_card;
    }
    if (text.contains('debito') || text.contains('débito') || text.contains('debit')) {
      return Icons.account_balance;
    }
    if (text.contains('pix') || text.contains('qr')) {
      return Icons.pix;
    }
    if (text.contains('dinheiro') || text.contains('cash')) {
      return Icons.attach_money;
    }
    if (text.contains('boleto')) {
      return Icons.receipt_long;
    }
    if (text.contains('transfer') || text.contains('bank')) {
      return Icons.account_balance_wallet;
    }
    return const IconData(_fallbackIconCode, fontFamily: 'MaterialIcons');
  }

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

  Future<void> _populateDefaults() async {
    if (_isPopulating) return;
    setState(() => _isPopulating = true);
    try {
      // Primeiro popula os métodos padrão
      await DatabaseInitializationService.instance
          .populatePaymentMethods(DatabaseHelper.instance);

      // Depois atribui logos inteligentes aos métodos existentes sem logo
      await _assignIntelligentLogos();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Padrões populados com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao popular padrões: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPopulating = false);
    }
  }

  /// Atribui logos (emojis) inteligentes a todos os métodos de pagamento
  /// que ainda não têm logo definido.
  Future<void> _assignIntelligentLogos() async {
    final db = DatabaseHelper.instance;
    final methods = await db.readPaymentMethods(onlyActive: false);

    for (final method in methods) {
      // Atribui logo se estiver vazio ou nulo
      if (method.logo == null || method.logo!.isEmpty) {
        final logo = DefaultAccountCategoriesService.getLogoForPaymentMethod(method.name);
        if (logo.isNotEmpty) {
          await db.updatePaymentMethod(method.copyWith(logo: logo));
        }
      }
    }
  }

  void _showPaymentMethodDialog({PaymentMethod? method}) {
    showDialog(
      context: context,
      builder: (context) {
        final isEditing = method != null;
        final nameController = TextEditingController(text: method?.name ?? '');
        final typeController = TextEditingController(text: method?.type ?? '');
        final usageNotifier = ValueNotifier<PaymentMethodUsage>(
          method?.usage ?? PaymentMethodUsage.pagamentosRecebimentos,
        );
        int selectedIconCode = method?.iconCode ?? _inferIcon(nameController.text, typeController.text).codePoint;
        // Tipos disponíveis (pode ser ajustado conforme necessidade)
        const paymentTypes = ['CASH', 'PIX', 'BANK_DEBIT', 'CREDIT_CARD'];

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
                    child: StatefulBuilder(
                      builder: (context, setStateDialog) {
                        return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? 'Editar Forma de Pagamento/Recebimento'
                              : 'Nova Forma de Pagamento/Recebimento',
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
	                        ValueListenableBuilder<PaymentMethodUsage>(
	                          valueListenable: usageNotifier,
	                          builder: (context, usage, _) {
	                            return DropdownButtonFormField<PaymentMethodUsage>(
	                              key: ValueKey(usage),
	                              initialValue: usage,
	                              decoration: buildOutlinedInputDecoration(
	                                label: 'Uso:',
	                                icon: Icons.swap_horiz,
	                              ),
	                              items: PaymentMethodUsage.values
	                                  .map((u) => DropdownMenuItem(
	                                        value: u,
	                                        child: Text(u.label),
	                                      ))
	                                  .toList(),
	                              onChanged: (value) {
	                                if (value == null) return;
	                                usageNotifier.value = value;
	                              },
	                            );
	                          },
	                        ),
	                        const SizedBox(height: 16),
	                        DropdownButtonFormField<String>(
                          initialValue: typeController.text.isNotEmpty ? typeController.text : null,
                          decoration: buildOutlinedInputDecoration(
                            label: 'Tipo',
                            icon: Icons.category,
                          ),
                          items: paymentTypes
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            // Atualiza controller para manter compatibilidade na gravação
                            typeController.text = value;
                            if (nameController.text.isEmpty) {
                              nameController.text = value;
                            }
                          },
                        ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  IconData(selectedIconCode, fontFamily: 'MaterialIcons'),
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Alterar ícone'),
                                  onPressed: () async {
                                    final picked = await showModalBottomSheet<int>(
                                      context: context,
                                      builder: (ctx) => SafeArea(
                                        child: GridView.builder(
                                          padding: const EdgeInsets.all(16),
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 4,
                                            mainAxisSpacing: 12,
                                            crossAxisSpacing: 12,
                                            childAspectRatio: 1,
                                          ),
                                          itemCount: _iconPalette.length,
                                          itemBuilder: (_, index) {
                                            final icon = _iconPalette[index];
                                            return InkWell(
                                              onTap: () => Navigator.pop(ctx, icon.codePoint),
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(icon, size: 28, color: Colors.grey.shade800),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                    if (picked != null) {
                                      setStateDialog(() => selectedIconCode = picked);
                                    }
                                  },
                                ),
                              ),
                            ],
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
                                final usage = usageNotifier.value;
                                final iconCode = selectedIconCode != 0
                                  ? selectedIconCode
                                  : _inferIcon(name, type).codePoint;

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
                                    const SnackBar(content: Text('Já existe uma forma de pagamento/recebimento com este nome')),
                                  );
                                  return;
                                }

                                // Salvar
                                if (isEditing) {
                                  await DatabaseHelper.instance.updatePaymentMethod(
	                                    method.copyWith(
	                                      name: name,
	                                      type: type,
	                                      usage: usage,
	                                    ),
                                  );
                                } else {
                                  await DatabaseHelper.instance.createPaymentMethod(
                                    PaymentMethod(
                                      name: name,
                                      type: type,
                                      iconCode: iconCode,
                                      requiresBank: false,
                                      isActive: true,
                                      usage: usage,
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
                        );
                      },
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
        title: const Text('Deletar Forma de Pagamento/Recebimento?'),
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
        return SafeArea(
          child: FutureBuilder<List<PaymentMethod>>(
            future: _futurePaymentMethods,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Erro: ${snapshot.error}'));
              }

              final methods = snapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Botões de ação
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _showPaymentMethodDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Novo Item'),
                      ),
                      FilledButton.icon(
                        onPressed: _isPopulating ? null : _populateDefaults,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Popular'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tabela
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).cardColor,
                    ),
                    child: Column(
                      children: [
                        // Cabeçalho
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              SizedBox(width: 8),
                              Text('Ações', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Lista vazia
                        if (methods.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('Nenhuma forma de pagamento/recebimento cadastrada'),
                            ),
                          ),
                        // Itens da lista
                        ...methods.map((method) => Container(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          height: 56,
                          child: Row(
                            children: [
                              if (method.logo != null && method.logo!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 14.0),
                                  child: Text(method.logo!, style: const TextStyle(fontSize: 26)),
                                ),
                              Expanded(
                                child: Text(method.name, style: const TextStyle(fontSize: 16)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showPaymentMethodDialog(method: method),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deletePaymentMethod(method),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
