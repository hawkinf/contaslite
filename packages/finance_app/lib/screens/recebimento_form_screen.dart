import 'package:flutter/material.dart';
import 'account_form_screen.dart';
import '../widgets/dialog_close_button.dart';

class RecebimentoFormScreen extends StatelessWidget {
  const RecebimentoFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;

    // Calcular dimensões responsivas - tamanho reduzido
    final maxWidth = (screenSize.width * 0.85).clamp(280.0, 500.0);
    final availableHeight = screenSize.height - viewInsets.bottom;
    final maxHeight = (availableHeight * 0.75).clamp(350.0, 700.0);

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
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
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Cabeçalho com título e botão fechar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Novo Recebimento',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DialogCloseButton(
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Formulário
              const Expanded(
                child: AccountFormScreen(
                  typeNameFilter: 'Recebimentos',
                  lockTypeSelection: true,
                  isRecebimento: true,
                  showAppBar: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
