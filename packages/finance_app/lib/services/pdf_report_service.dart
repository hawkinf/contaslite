import 'dart:typed_data';

import 'package:brasil_fields/brasil_fields.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/account.dart';
import '../models/contas_view_state.dart';

class PdfReportService {
  static final PdfReportService instance = PdfReportService._();

  PdfReportService._();

  Future<Uint8List> buildContasPdf(ContasViewState state) async {
    final doc = pw.Document();
    final dateFormatter = DateFormat('dd/MM/yyyy');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            _buildHeader(state),
            pw.SizedBox(height: 10),
            _buildFiltersLine(state),
            pw.SizedBox(height: 16),
            _buildSummaryCards(state),
            pw.SizedBox(height: 18),
            pw.Text(
              'Lista de contas',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            ..._buildGroupedEntries(state, dateFormatter),
            pw.SizedBox(height: 20),
            _buildFooter(),
          ];
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _buildHeader(ContasViewState state) {
    final subtitle = _formatSubtitle(state);
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'FácilFin - Relatório de Contas',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
          ),
          if (state.city != null && state.city!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              state.city!.trim(),
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 6),
          pw.Text(
            'Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFiltersLine(ContasViewState state) {
    final parts = <String>[
      'Filtros: ${state.filterLabel}',
      state.hidePaidAccounts ? 'Ocultar pagas' : 'Pagas visíveis',
      'Período: ${state.periodFilterLabel}',
    ];
    if (state.additionalFiltersLabel != null && state.additionalFiltersLabel!.trim().isNotEmpty) {
      parts.add(state.additionalFiltersLabel!.trim());
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        parts.join(' | '),
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  pw.Widget _buildSummaryCards(ContasViewState state) {
    return pw.Row(
      children: [
        _buildSummaryCard(
          title: 'A PAGAR',
          value: UtilBrasilFields.obterReal(state.totalLancadoPagar),
          forecast: 'Previsto: ${UtilBrasilFields.obterReal(state.totalPrevistoPagar)}',
          color: PdfColors.red700,
        ),
        pw.SizedBox(width: 8),
        _buildSummaryCard(
          title: 'A RECEBER',
          value: UtilBrasilFields.obterReal(state.totalLancadoReceber),
          forecast: 'Previsto: ${UtilBrasilFields.obterReal(state.totalPrevistoReceber)}',
          color: PdfColors.green700,
        ),
        pw.SizedBox(width: 8),
        _buildSummaryCard(
          title: 'SALDO PROJETADO',
          value: UtilBrasilFields.obterReal(
            (state.totalLancadoReceber + state.totalPrevistoReceber) -
                (state.totalLancadoPagar + state.totalPrevistoPagar),
          ),
          forecast: 'Resultado estimado',
          color: PdfColors.blue700,
        ),
      ],
    );
  }

  pw.Widget _buildSummaryCard({
    required String title,
    required String value,
    required String forecast,
    required PdfColor color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              forecast,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<pw.Widget> _buildGroupedEntries(
    ContasViewState state,
    DateFormat dateFormatter,
  ) {
    final widgets = <pw.Widget>[];

    for (final group in state.groups) {
      widgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            _formatGroupLabel(group.date, dateFormatter),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 6));

      for (int i = 0; i < group.items.length; i++) {
        widgets.add(_buildEntryRow(state, group.items[i]));
        if (i != group.items.length - 1) {
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Divider(color: PdfColors.grey300, height: 1));
          widgets.add(pw.SizedBox(height: 6));
        }
      }

      widgets.add(pw.SizedBox(height: 12));
    }

    return widgets;
  }

  pw.Widget _buildEntryRow(ContasViewState state, Account account) {
    final typeName = state.typeNames[account.typeId] ?? 'Outro';
    final isRecebimento = typeName.toLowerCase().contains('receb');
    final isCard = account.cardBrand != null || account.cardBank != null;
    final payment = account.id != null ? state.paymentInfo[account.id] : null;
    final isPaid = payment != null && (payment['isPaid'] as bool? ?? false);

    final description = account.description.isNotEmpty ? account.description : 'Sem descrição';
    final categoryName = _resolveCategoryLabel(state, account, typeName);
    final statusLabel = isPaid ? 'Pago' : 'Pendente';
    final typeLabel = isCard ? 'Cartão' : (account.isRecurrent ? 'Recorrente' : 'Avulsa');

    PdfColor valueColor = PdfColors.grey800;
    if (isCard) {
      valueColor = PdfColors.purple700;
    } else if (isRecebimento) {
      valueColor = PdfColors.green700;
    } else {
      valueColor = PdfColors.red700;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  description,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  maxLines: 2,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                UtilBrasilFields.obterReal(account.value),
                style: pw.TextStyle(fontSize: 10, color: valueColor, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '$categoryName - $typeLabel',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
            maxLines: 1,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            statusLabel,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  String _resolveCategoryLabel(ContasViewState state, Account account, String typeName) {
    if (account.cardBrand != null || account.cardBank != null) {
      final bank = account.cardBank?.trim() ?? '';
      final brand = account.cardBrand?.trim() ?? '';
      final label = '$bank $brand'.trim();
      return label.isNotEmpty ? label : 'Cartão de crédito';
    }

    final categoryId = account.categoryId;
    if (categoryId != null) {
      final child = state.categoryNames[categoryId];
      final parent = state.categoryParentNames[categoryId];
      if (child != null && parent != null && parent.trim().isNotEmpty) {
        return '$parent > $child';
      }
      if (child != null && child.trim().isNotEmpty) {
        return child;
      }
    }

    return typeName;
  }

  String _formatGroupLabel(DateTime date, DateFormat dateFormatter) {
    final dayName = DateFormat('EEEE', 'pt_BR').format(date).toUpperCase();
    return '${dateFormatter.format(date)} - $dayName';
  }

  pw.Widget _buildFooter() {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'FácilFin · Relatório gerado automaticamente',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  String _formatSubtitle(ContasViewState state) {
    final raw = state.periodLabel;
    return raw
        .replaceAll('—', '-')
        .replaceAll('•', '-')
        .replaceAll('·', '-')
        .replaceAll('  ', ' ')
        .trim();
  }
}
