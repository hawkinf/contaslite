import 'package:flutter/material.dart';
import 'account_form_screen.dart';
import '../widgets/dialog_close_button.dart';

class RecebimentoFormScreen extends StatelessWidget {
  const RecebimentoFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;

    // Calcular dimensões responsivas
    final maxWidth = (screenSize.width * 0.9).clamp(280.0, 600.0);
    final availableHeight = screenSize.height - viewInsets.bottom;
    final maxHeight = (availableHeight * 0.85).clamp(400.0, 900.0);

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
          child: Stack(
            children: [
              const AccountFormScreen(
                typeNameFilter: 'Recebimentos',
                lockTypeSelection: true,
                isRecebimento: true,
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
  }
}
