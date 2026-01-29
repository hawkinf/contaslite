import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../models/bank_account.dart';
import '../services/bank_service.dart';
import '../widgets/app_input_decoration.dart';
import '../services/prefs_service.dart';
import '../utils/color_contrast.dart';
import '../ui/components/ff_design_system.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_radius.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  List<BankAccount> _items = [];
  List<BankInfo> _banks = [];
  bool _loading = true;

  final List<Color> _bankColors = const [
    Color(0xFF1565C0),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFF4511E),
    Color(0xFFFFC107),
    Color(0xFF6D4C41),
    Color(0xFFAB47BC),
    Color(0xFF00897B),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ];
  static const int _defaultBankColor = 0xFF1565C0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final saved = await DatabaseHelper.instance.readBankAccounts();
      List<BankInfo> fetched = [];
      try {
        fetched = await BankService.instance.fetchBanks();
      } catch (_) {}
      fetched.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _items = saved;
        _banks = fetched;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _banks = [];
        _loading = false;
      });
    }
  }

  String _formatBankCode(int code) => code.toString().padLeft(3, '0');

  Widget _buildBankSearchField({
    required BankInfo? initialBank,
    required Function(BankInfo?) onChanged,
    required List<BankInfo> allBanks,
    required BankInfo? fallbackBank,
    required TextEditingController descriptionController,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        List<BankInfo> filteredBanks = [...allBanks];
        if (fallbackBank != null && !filteredBanks.contains(fallbackBank)) {
          filteredBanks.add(fallbackBank);
        }
        filteredBanks.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return Autocomplete<BankInfo>(
          displayStringForOption: (BankInfo option) =>
              '${_formatBankCode(option.code)} - ${option.name}',
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return filteredBanks;
            }
            final query = textEditingValue.text.toLowerCase();
            return filteredBanks.where((bank) {
              final code = _formatBankCode(bank.code).toLowerCase();
              final name = bank.name.toLowerCase();
              return code.contains(query) || name.contains(query);
            }).toList();
          },
          onSelected: (BankInfo selection) {
            onChanged(selection);
            if (descriptionController.text.isEmpty) {
              descriptionController.text = selection.name;
            }
          },
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            if (initialBank != null && textEditingController.text.isEmpty) {
              textEditingController.text =
                  '${_formatBankCode(initialBank.code)} - ${initialBank.name}';
            }
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: buildOutlinedInputDecoration(
                label: 'Banco (código + nome)',
                icon: Icons.account_balance,
              ),
              onChanged: (value) {
                setState(() {});
              },
              validator: (v) => (v == null || v.isEmpty) ? 'Selecione o banco' : null,
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 300,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final BankInfo option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            '${_formatBankCode(option.code)} - ${option.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  BankInfo? _findBankInfo(int code) {
    for (final bank in _banks) {
      if (bank.code == code) return bank;
    }
    return null;
  }

  Future<void> _openForm({BankAccount? bank}) async {
    final formKey = GlobalKey<FormState>();
    final descriptionCtrl = TextEditingController(text: bank?.description ?? '');
    final agencyCtrl = TextEditingController(text: bank?.agency ?? '');
    final accountCtrl = TextEditingController(text: bank?.account ?? '');
    int selectedColorValue = bank?.color ?? _defaultBankColor;

    BankInfo? selectedBank = bank != null ? _findBankInfo(bank.code) : null;
    BankInfo? fallbackBank;
    if (bank != null && selectedBank == null) {
      fallbackBank = BankInfo(code: bank.code, name: bank.name);
      selectedBank = fallbackBank;
    }

    if (bank == null && descriptionCtrl.text.isEmpty && selectedBank != null) {
      descriptionCtrl.text = selectedBank.name;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final viewInsets = media.viewInsets.bottom;
        final maxWidth = media.size.width <= 520 ? media.size.width * 0.95 : 420.0;
        final maxHeight = media.size.height * 0.75;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(bottom: viewInsets, left: 16, right: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: Material(
                    color: Theme.of(ctx).colorScheme.surface,
                    elevation: 10,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance,
                                  color: Theme.of(ctx).colorScheme.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    bank == null ? 'Adicionar Banco' : 'Editar Banco',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextFormField(
                              controller: descriptionCtrl,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: buildOutlinedInputDecoration(
                                label: 'Descrição / Tipo da Conta',
                                icon: Icons.badge_outlined,
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Informe a descrição' : null,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Escolha uma cor',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _bankColors.map((color) {
                                final isSelected = selectedColorValue == color.toARGB32();
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () => setModalState(() {
                                      selectedColorValue = color.toARGB32();
                                    }),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? foregroundColorFor(color)
                                              : Colors.grey.shade300,
                                          width: isSelected ? 3 : 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              Icons.check,
                                              size: 18,
                                              color: foregroundColorFor(color),
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _buildBankSearchField(
                              initialBank: selectedBank,
                              onChanged: (val) => setModalState(() => selectedBank = val),
                              allBanks: _banks,
                              fallbackBank: fallbackBank,
                              descriptionController: descriptionCtrl,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: agencyCtrl,
                              decoration: buildOutlinedInputDecoration(
                                label: 'Agência',
                                icon: Icons.home_work,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))
                              ],
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Informe a agência' : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: accountCtrl,
                              decoration: buildOutlinedInputDecoration(
                                label: 'C/C',
                                icon: Icons.account_balance_wallet,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))
                              ],
                              validator: (v) => v == null || v.isEmpty ? 'Informe a conta' : null,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            FFPrimaryButton(
                              label: bank == null ? 'Salvar' : 'Atualizar',
                              icon: Icons.save,
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final newBank = BankAccount(
                                  id: bank?.id,
                                  code: selectedBank!.code,
                                  name: selectedBank!.name,
                                  description: descriptionCtrl.text.trim(),
                                  agency: agencyCtrl.text.trim(),
                                  account: accountCtrl.text.trim(),
                                  color: selectedColorValue,
                                );
                                if (bank == null) {
                                  await DatabaseHelper.instance.createBankAccount(newBank);
                                } else {
                                  await DatabaseHelper.instance.updateBankAccount(newBank);
                                }
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                _loadData();
                              },
                            ),
                            if (bank != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Excluir banco'),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  if (bank.id != null) {
                                    _deleteBank(bank.id!);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteBank(int id) async {
    final confirm = await FFConfirmDialog.show(
      context: context,
      title: 'Excluir banco?',
      message: 'Esta conta bancária será removida permanentemente.',
      confirmLabel: 'Excluir',
      isDanger: true,
      icon: Icons.delete_outline,
    );

    if (confirm) {
      await DatabaseHelper.instance.deleteBankAccount(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FFScreenScaffold(
      title: 'Contas Bancárias',
      useScrollView: false,
      verticalPadding: 0,
      child: ValueListenableBuilder<DateTimeRange>(
        valueListenable: PrefsService.dateRangeNotifier,
        builder: (context, range, _) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Actions bar
              Padding(
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.md),
                child: FFEntityActionsBar(
                  primaryAction: FFEntityAction(
                    label: 'Novo Banco',
                    icon: Icons.add,
                    onPressed: (_banks.isEmpty && !_loading)
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Carregando lista de bancos, tente novamente.'),
                              ),
                            )
                        : _openForm,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: _items.isEmpty
                    ? FFEmptyState.bancos(
                        onAction: _banks.isNotEmpty ? _openForm : null,
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
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final bank = _items[index];
        return _BankAccountCard(
          bank: bank,
          onTap: () => _openForm(bank: bank),
          onEdit: () => _openForm(bank: bank),
          onDelete: bank.id != null ? () => _deleteBank(bank.id!) : null,
        );
      },
    );
  }
}

/// Card de conta bancária no estilo FF*
class _BankAccountCard extends StatelessWidget {
  final BankAccount bank;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _BankAccountCard({
    required this.bank,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  String _formatBankCode(int code) => code.toString().padLeft(3, '0');

  @override
  Widget build(BuildContext context) {
    final Color cardColor = Color(bank.color);
    final Color textColor = foregroundColorFor(cardColor);
    final Color subtleTextColor = textColor.withValues(alpha: 0.78);

    return FFCard(
      padding: EdgeInsets.zero,
      backgroundColor: cardColor,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color bar
            Container(
              width: 6,
              height: 50,
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatBankCode(bank.code)} - ${bank.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bank.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: subtleTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.account_balance, size: 14, color: subtleTextColor),
                      const SizedBox(width: 4),
                      Text(
                        'Ag: ',
                        style: TextStyle(fontSize: 11, color: subtleTextColor),
                      ),
                      Text(
                        bank.agency,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Icon(Icons.numbers, size: 14, color: subtleTextColor),
                      const SizedBox(width: 4),
                      Text(
                        'C/C: ',
                        style: TextStyle(fontSize: 11, color: subtleTextColor),
                      ),
                      Text(
                        bank.account,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                FFIconActionButton(
                  icon: Icons.edit_outlined,
                  onPressed: onEdit ?? () {},
                  iconColor: textColor.withValues(alpha: 0.8),
                  tooltip: 'Editar',
                ),
                FFIconActionButton.danger(
                  icon: Icons.delete_outline,
                  onPressed: onDelete ?? () {},
                  tooltip: 'Excluir',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
