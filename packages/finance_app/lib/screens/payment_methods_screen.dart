import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/payment_method.dart';
import '../services/database_initialization_service.dart';
import '../services/default_account_categories_service.dart';
import '../widgets/app_input_decoration.dart';
import '../services/prefs_service.dart';
import '../ui/components/ff_design_system.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_radius.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<PaymentMethod> _methods = [];
  bool _isLoading = true;
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

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoading = true);
    try {
      final methods = await DatabaseHelper.instance.readPaymentMethods(onlyActive: false);
      if (mounted) {
        setState(() {
          _methods = methods;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _methods = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _populateDefaults() async {
    if (_isPopulating) return;
    setState(() => _isPopulating = true);
    try {
      await DatabaseInitializationService.instance
          .populatePaymentMethods(DatabaseHelper.instance);
      await _assignIntelligentLogos();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Padrões populados com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadPaymentMethods();
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

  Future<void> _assignIntelligentLogos() async {
    final db = DatabaseHelper.instance;
    final methods = await db.readPaymentMethods(onlyActive: false);

    for (final method in methods) {
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
        int selectedIconCode =
            method?.iconCode ?? _inferIcon(nameController.text, typeController.text).codePoint;
        const paymentTypes = ['CASH', 'PIX', 'BANK_DEBIT', 'CREDIT_CARD'];

        if (!isEditing && nameController.text.isEmpty && typeController.text.isNotEmpty) {
          nameController.text = typeController.text;
        }

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(
                            Icons.payment,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              isEditing
                                  ? 'Editar Forma de Pagamento'
                                  : 'Nova Forma de Pagamento',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextField(
                        controller: nameController,
                        decoration: buildOutlinedInputDecoration(
                          label: 'Nome',
                          icon: Icons.payment,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
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
                      const SizedBox(height: AppSpacing.lg),
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
                          typeController.text = value;
                          if (nameController.text.isEmpty) {
                            nameController.text = value;
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(
                              IconData(selectedIconCode, fontFamily: 'MaterialIcons'),
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: FFSecondaryButton(
                              label: 'Alterar ícone',
                              icon: Icons.edit,
                              onPressed: () async {
                                final picked = await showModalBottomSheet<int>(
                                  context: context,
                                  builder: (ctx) => SafeArea(
                                    child: GridView.builder(
                                      padding: const EdgeInsets.all(AppSpacing.lg),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                                          borderRadius: BorderRadius.circular(AppRadius.md),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(AppRadius.md),
                                            ),
                                            child: Icon(icon,
                                                size: 28, color: Colors.grey.shade800),
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
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FFSecondaryButton(
                            label: 'Cancelar',
                            expanded: false,
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          FFPrimaryButton(
                            label: isEditing ? 'Salvar' : 'Criar',
                            expanded: false,
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

                              final exists = await DatabaseHelper.instance
                                  .checkPaymentMethodExists(name, excludeId: method?.id);
                              if (!context.mounted) return;

                              if (exists) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Já existe uma forma de pagamento com este nome')),
                                );
                                return;
                              }

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
                              _loadPaymentMethods();
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePaymentMethod(PaymentMethod method) async {
    final confirm = await FFConfirmDialog.showDelete(
      context: context,
      itemName: method.name,
    );

    if (confirm) {
      await DatabaseHelper.instance.deletePaymentMethod(method.id!);
      _loadPaymentMethods();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FFScreenScaffold(
      title: 'Formas de Pagamento',
      useScrollView: false,
      verticalPadding: 0,
      child: ValueListenableBuilder<DateTimeRange>(
        valueListenable: PrefsService.dateRangeNotifier,
        builder: (context, range, _) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Actions bar
              Padding(
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.md),
                child: FFEntityActionsBar(
                  primaryAction: FFEntityAction(
                    label: 'Novo Item',
                    icon: Icons.add,
                    onPressed: () => _showPaymentMethodDialog(),
                  ),
                  secondaryAction: FFEntityAction(
                    label: 'Popular',
                    icon: Icons.auto_awesome,
                    onPressed: _isPopulating ? null : _populateDefaults,
                    isLoading: _isPopulating,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: _methods.isEmpty
                    ? FFEmptyState.formasPagamento(
                        onAction: () => _showPaymentMethodDialog(),
                      )
                    : _buildList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FFCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Descrição',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  'Ações',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: _methods.length,
              itemBuilder: (context, index) {
                final method = _methods[index];
                return FFEntityListItem.paymentMethod(
                  emoji: method.logo,
                  icon: IconData(method.iconCode, fontFamily: 'MaterialIcons'),
                  name: method.name,
                  type: method.type,
                  onEdit: () => _showPaymentMethodDialog(method: method),
                  onDelete: () => _deletePaymentMethod(method),
                  showDivider: index < _methods.length - 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
