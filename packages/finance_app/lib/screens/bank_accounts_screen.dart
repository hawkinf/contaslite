import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../models/bank_account.dart';
import '../services/bank_service.dart';
import '../widgets/app_input_decoration.dart';
import '../services/prefs_service.dart';
import '../utils/color_contrast.dart';

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
      fetched
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
        final searchCtrl = TextEditingController();
        List<BankInfo> filteredBanks = [...allBanks];
        if (fallbackBank != null && !filteredBanks.contains(fallbackBank)) {
          filteredBanks.add(fallbackBank);
        }
        filteredBanks.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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
            searchCtrl.text =
                '${_formatBankCode(selection.code)} - ${selection.name}';
            onChanged(selection);
            // Atualizar descrição com o nome do banco
            if (descriptionController.text.isEmpty) {
              descriptionController.text = selection.name;
            }
          },
          fieldViewBuilder: (context, textEditingController, focusNode,
              onFieldSubmitted) {
            if (initialBank != null && textEditingController.text.isEmpty) {
              textEditingController.text =
                  '${_formatBankCode(initialBank.code)} - ${initialBank.name}';
            }
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: buildOutlinedInputDecoration(
                label: 'Banco (codigo + nome)',
                icon: Icons.account_balance,
              ),
              onChanged: (value) {
                setState(() {});
              },
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Selecione o banco' : null,
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
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
    final descriptionCtrl =
        TextEditingController(text: bank?.description ?? '');
    final agencyCtrl = TextEditingController(text: bank?.agency ?? '');
    final accountCtrl = TextEditingController(text: bank?.account ?? '');
    int selectedColorValue = bank?.color ?? _defaultBankColor;

    BankInfo? selectedBank = bank != null ? _findBankInfo(bank.code) : null;
    BankInfo? fallbackBank;
    if (bank != null && selectedBank == null) {
      fallbackBank = BankInfo(code: bank.code, name: bank.name);
      selectedBank = fallbackBank;
    }

    // Se é novo banco e não há descrição, usar o nome do banco como padrão
    if (bank == null && descriptionCtrl.text.isEmpty && selectedBank != null) {
      descriptionCtrl.text = selectedBank.name;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final viewInsets = media.viewInsets.bottom;
        final maxWidth =
            media.size.width <= 520 ? media.size.width * 0.95 : 420.0;
        final maxHeight = media.size.height * 0.7;

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
                    borderRadius: BorderRadius.circular(18),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: bank == null
                                      ? const Text('Adicionar Banco', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                                      : const Text('Editar Banco', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Fechar',
                                  onPressed: () => Navigator.of(ctx).pop(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: descriptionCtrl,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: buildOutlinedInputDecoration(
                                label: 'Descrição / Tipo da Conta',
                                icon: Icons.badge_outlined,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Informe a descrição'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Escolha uma cor',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _bankColors.map((color) {
                                final isSelected =
                                    selectedColorValue == color.toARGB32();
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
                            const SizedBox(height: 16),
                            _buildBankSearchField(
                              initialBank: selectedBank,
                              onChanged: (val) => setModalState(() => selectedBank = val),
                              allBanks: _banks,
                              fallbackBank: fallbackBank,
                              descriptionController: descriptionCtrl,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: agencyCtrl,
                              decoration: buildOutlinedInputDecoration(
                                  label: 'Agencia', icon: Icons.home_work),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9-]'))
                              ],
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Informe a agencia'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: accountCtrl,
                              decoration: buildOutlinedInputDecoration(
                                  label: 'C/C',
                                  icon: Icons.account_balance_wallet),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9-]'))
                              ],
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Informe a conta'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              icon: const Icon(Icons.save),
                              label:
                                  Text(bank == null ? 'Salvar' : 'Atualizar'),
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
                                  await DatabaseHelper.instance
                                      .createBankAccount(newBank);
                                } else {
                                  await DatabaseHelper.instance
                                      .updateBankAccount(newBank);
                                }
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                _loadData();
                              },
                            ),
                            if (bank != null) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir banco?'),
        content: const Text('Essa conta bancaria sera removida.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteBankAccount(id);
      _loadData();
    }
  }



  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        return Scaffold(
          appBar: AppBar(
            // Título removido para evitar duplicidade
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: (_banks.isEmpty && !_loading)
                                ? () => ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Carregando lista de bancos, tente novamente.',
                                            ),
                                          ),
                                        )
                                : _openForm,
                            icon: const Icon(Icons.add),
                            label: const Text('Novo Banco'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _items.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhum banco salvo.\nUse "Novo Banco" para adicionar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final bank = _items[index];
                                final Color cardColor = Color(bank.color);
                                final Color borderColor = cardColor.withValues(alpha: 0.85);
                                final Color textColor = foregroundColorFor(cardColor);
                                final Color subtleTextColor = textColor.withValues(alpha: 0.78);
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  elevation: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: borderColor, width: 2),
                                  ),
                                  color: cardColor,
                                  child: InkWell(
                                    onTap: () => _openForm(bank: bank),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: borderColor,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                              Text(
                                                '${_formatBankCode(bank.code)} - ${bank.name}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16.8,
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
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons.account_balance, size: 16, color: subtleTextColor),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Agência: ',
                                                    style: TextStyle(fontSize: 11, color: subtleTextColor),
                                                  ),
                                                  Text(
                                                    bank.agency,
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(Icons.numbers, size: 16, color: subtleTextColor),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Conta: ',
                                                    style: TextStyle(fontSize: 11, color: subtleTextColor),
                                                  ),
                                                  Text(
                                                    bank.account,
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Tooltip(
                                                    message: 'Editar',
                                                    child: IconButton(
                                                      icon: const Icon(Icons.edit, color: Colors.blue, size: 22),
                                                      onPressed: () => _openForm(bank: bank),
                                                    ),
                                                  ),
                                                  Tooltip(
                                                    message: 'Excluir',
                                                    child: IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                                                      onPressed: bank.id != null ? () => _deleteBank(bank.id!) : null,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
