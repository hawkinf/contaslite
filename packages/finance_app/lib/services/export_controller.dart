import 'package:flutter/material.dart';

import '../widgets/calendar_export_view.dart';
import '../widgets/contas_export_view.dart';
import 'prefs_service.dart';
import 'visual_pdf_export_service.dart';

/// Tipo de exportação disponível
enum ExportType {
  /// Exportação visual (captura da tela como imagem)
  visual,

  /// Exportação tabular (relatório em tabelas)
  tabular,
}

/// Controller para gerenciar exportações de PDF.
///
/// Coordena a captura do estado atual da tela e delegação
/// para o serviço de exportação apropriado.
class ExportController {
  ExportController();

  bool _isExporting = false;

  /// Verifica se uma exportação está em andamento.
  bool get isExporting => _isExporting;

  /// Exporta a view atual para PDF.
  ///
  /// [selectedIndex] - Índice da aba atual (0=Contas, 1=Calendário, etc.)
  /// [currentTabName] - Nome da aba para mensagens
  /// [exportType] - Tipo de exportação (visual ou tabular)
  Future<void> exportCurrentViewToPdf({
    required BuildContext context,
    required int selectedIndex,
    required String currentTabName,
    ExportType exportType = ExportType.visual,
  }) async {
    if (_isExporting) return;
    _isExporting = true;

    try {
      switch (selectedIndex) {
        case 0: // Contas
          await _exportContasToPdf(context, exportType);
          break;
        case 1: // Calendário
          await _exportCalendarToPdf(context, exportType);
          break;
        default:
          _showSnack(context, 'Exportação de "$currentTabName" em breve!');
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Erro ao exportar PDF: $e', isError: true);
      }
    } finally {
      _isExporting = false;
    }
  }

  /// Exporta a tela de Contas para PDF.
  Future<void> _exportContasToPdf(BuildContext context, ExportType exportType) async {
    final provider = PrefsService.dashboardExportStateProvider;
    if (provider == null) {
      _showSnack(context, 'Aguarde o carregamento das contas...');
      return;
    }

    final snapshot = provider();
    if (snapshot == null) {
      _showSnack(context, 'Não foi possível capturar os dados atuais.');
      return;
    }

    // Mostrar diálogo de progresso
    late StateSetter dialogSetState;
    double progress = 0.0;
    String stage = 'Iniciando...';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            return PopScope(
              canPop: false,
              child: AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            value: progress > 0 ? progress : null,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gerando PDF Visual...',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stage,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (progress > 0) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: progress),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    try {
      // Determinar configuração baseada na plataforma
      final config = VisualPdfExportConfig.windows;

      // Exportar usando o serviço visual
      await VisualPdfExportService.instance.exportWidgetToPdf(
        context: context,
        widgetBuilder: (ctx) => ContasExportView(snapshot: snapshot),
        fileBaseName: 'facilfin_contas_${snapshot.filterLabel.toLowerCase().replaceAll(' ', '_')}',
        config: config,
        onProgress: (p, s) {
          dialogSetState(() {
            progress = p;
            stage = s;
          });
        },
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack(context, 'PDF exportado com sucesso!');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack(context, 'Erro ao exportar PDF: $e', isError: true);
      }
      rethrow;
    }
  }

  /// Exporta a tela de Calendário para PDF.
  Future<void> _exportCalendarToPdf(BuildContext context, ExportType exportType) async {
    final provider = PrefsService.calendarExportStateProvider;
    if (provider == null) {
      _showSnack(context, 'Aguarde o carregamento do calendário...');
      return;
    }

    final snapshot = provider();
    if (snapshot == null) {
      _showSnack(context, 'Não foi possível capturar os dados do calendário.');
      return;
    }

    // Mostrar diálogo de progresso
    late StateSetter dialogSetState;
    double progress = 0.0;
    String stage = 'Iniciando...';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            return PopScope(
              canPop: false,
              child: AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            value: progress > 0 ? progress : null,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gerando PDF do Calendário...',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stage,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (progress > 0) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: progress),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    try {
      // Determinar configuração baseada na plataforma
      final config = VisualPdfExportConfig.windows;

      // Gerar nome do arquivo baseado no modo e período
      final modeLabel = snapshot.mode.name;
      final periodLabel = snapshot.periodLabel.toLowerCase().replaceAll(' ', '_');

      // Exportar usando o serviço visual
      await VisualPdfExportService.instance.exportWidgetToPdf(
        context: context,
        widgetBuilder: (ctx) => CalendarExportView(snapshot: snapshot),
        fileBaseName: 'facilfin_calendario_${modeLabel}_$periodLabel',
        config: config,
        onProgress: (p, s) {
          dialogSetState(() {
            progress = p;
            stage = s;
          });
        },
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack(context, 'PDF do Calendário exportado com sucesso!');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnack(context, 'Erro ao exportar PDF: $e', isError: true);
      }
      rethrow;
    }
  }

  /// Exibe um snackbar com mensagem.
  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;

    final color = isError ? Colors.red.shade600 : Colors.blue.shade600;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
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
