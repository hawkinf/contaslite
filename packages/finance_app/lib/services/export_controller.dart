import 'package:flutter/material.dart';

import '../models/account.dart';
import '../services/pdf_export_service.dart';
import 'prefs_service.dart';

class ExportController {
  ExportController();

  bool _isExporting = false;

  Future<void> exportCurrentViewToPdf({
    required BuildContext context,
    required int selectedIndex,
    required String currentTabName,
  }) async {
    if (_isExporting) return;
    _isExporting = true;

    if (selectedIndex != 0) {
      _showSnack(context, 'Exportação de "$currentTabName" em breve!');
      _isExporting = false;
      return;
    }

    final provider = PrefsService.dashboardExportStateProvider;
    if (provider == null) {
      _showSnack(context, 'Aguarde o carregamento das contas...');
      _isExporting = false;
      return;
    }

    final state = provider();
    if (state == null) {
      _showSnack(context, 'Não foi possível capturar os dados atuais.');
      _isExporting = false;
      return;
    }

    try {
      _showProgressDialog(context);

      // Converter grupos em lista plana de contas
      final accounts = <Account>[];
      for (final group in state.groups) {
        accounts.addAll(group.items);
      }

      // Criar dados de exportação
      final exportData = DashboardExportData(
        accounts: accounts,
        filterLabel: state.filterLabel,
        periodLabel: state.periodLabel,
        totalLancadoPagar: state.totalLancadoPagar,
        totalLancadoReceber: state.totalLancadoReceber,
        totalPrevistoPagar: state.totalPrevistoPagar,
        totalPrevistoReceber: state.totalPrevistoReceber,
        hidePaidAccounts: state.hidePaidAccounts,
        typeNames: state.typeNames,
        categoryNames: state.categoryNames,
        paymentInfo: state.paymentInfo,
      );

      // Gerar e compartilhar PDF
      await PdfExportService.instance.exportDashboardToPdf(exportData);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack(context, 'PDF exportado com sucesso!');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack(context, 'Erro ao exportar PDF: $e', isError: true);
      }
    } finally {
      _isExporting = false;
    }
  }

  void _showProgressDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Gerando relatório PDF...')),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    final color = isError ? Colors.red.shade600 : Colors.blue.shade600;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
