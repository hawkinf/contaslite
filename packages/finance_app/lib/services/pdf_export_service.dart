import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import 'package:intl/intl.dart';
import 'package:brasil_fields/brasil_fields.dart';

/// Dados para exportação do dashboard com filtros
class DashboardExportData {
  final List<Account> accounts;
  final String filterLabel;
  final String periodLabel;
  final double totalLancadoPagar;
  final double totalLancadoReceber;
  final double totalPrevistoPagar;
  final double totalPrevistoReceber;
  final bool hidePaidAccounts;
  final Map<int, String> typeNames;
  final Map<int, String> categoryNames;
  final Map<int, Map<String, dynamic>> paymentInfo;

  const DashboardExportData({
    required this.accounts,
    required this.filterLabel,
    required this.periodLabel,
    required this.totalLancadoPagar,
    required this.totalLancadoReceber,
    required this.totalPrevistoPagar,
    required this.totalPrevistoReceber,
    required this.hidePaidAccounts,
    required this.typeNames,
    required this.categoryNames,
    required this.paymentInfo,
  });
}

class PdfExportService {
  static final PdfExportService instance = PdfExportService._init();

  PdfExportService._init();

  Future<Uint8List> buildPdfFromSlices(
    List<Uint8List> slices, {
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    double margin = 14,
  }) async {
    final doc = pw.Document();
    final pageMargin = pw.EdgeInsets.all(margin);

    for (final slice in slices) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pageMargin,
          build: (context) {
            return pw.Center(
              child: pw.Image(
                pw.MemoryImage(slice),
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  Future<void> exportAllDataToPdf() async {
    try {
      final doc = pw.Document();

      // Obter todos os dados do banco
      final accounts = await DatabaseHelper.instance.readAllAccountsRaw();
      final types = await DatabaseHelper.instance.readAllTypes();
      final categories = await DatabaseHelper.instance.readAllAccountCategories();
      final payments = await DatabaseHelper.instance.readAllPayments();
      final banks = await DatabaseHelper.instance.readBankAccounts();
      final paymentMethods = await DatabaseHelper.instance.readPaymentMethods();

      // Página de capa
      doc.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'RELATÓRIO COMPLETO DO BANCO DE DADOS',
                  style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'ContasLite - Sistema de Controle Financeiro',
                  style: const pw.TextStyle(fontSize: 16),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 40),
                pw.Text(
                  'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Total de Registros:',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text('• Contas: ${accounts.length}'),
                pw.Text('• Tipos: ${types.length}'),
                pw.Text('• Categorias: ${categories.length}'),
                pw.Text('• Pagamentos: ${payments.length}'),
                pw.Text('• Contas Bancárias: ${banks.length}'),
                pw.Text('• Formas de Pagamento/Recebimento: ${paymentMethods.length}'),
              ],
            ),
          ),
        ),
      );

      // Página de Contas
      if (accounts.isNotEmpty) {
        doc.addPage(
          pw.Page(
            build: (pw.Context context) => pw.Column(
              children: [
                pw.Text(
                  'CONTAS (${accounts.length} registros)',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Cabeçalho
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Descrição', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Valor', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Data', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Dados
                    ...accounts.take(50).map((account) {
                      final date = account.month != null && account.year != null
                          ? '${account.dueDay}/${account.month}/${account.year}'
                          : '-';
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${account.id}', style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(account.description, style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              'R\$ ${account.value.toStringAsFixed(2)}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(date, style: const pw.TextStyle(fontSize: 10)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                if (accounts.length > 50)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 10),
                    child: pw.Text(
                      '... e mais ${accounts.length - 50} registros',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      // Página de Tipos
      if (types.isNotEmpty) {
        doc.addPage(
          pw.Page(
            build: (pw.Context context) => pw.Column(
              children: [
                pw.Text(
                  'TIPOS DE CONTA (${types.length} registros)',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(3),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Nome', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...types.map((type) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${type.id}', style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(type.name, style: const pw.TextStyle(fontSize: 10)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      }

      // Página de Categorias
      if (categories.isNotEmpty) {
        doc.addPage(
          pw.Page(
            build: (pw.Context context) => pw.Column(
              children: [
                pw.Text(
                  'CATEGORIAS (${categories.length} registros)',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Tipo ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Categoria', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...categories.map((cat) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${cat.id}', style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${cat.accountId}', style: const pw.TextStyle(fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(cat.categoria, style: const pw.TextStyle(fontSize: 10)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      }

      // Página de Pagamentos
      if (payments.isNotEmpty) {
        doc.addPage(
          pw.Page(
            build: (pw.Context context) => pw.Column(
              children: [
                pw.Text(
                  'PAGAMENTOS (${payments.length} registros)',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.8),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Conta ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Valor', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Data Pgto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                      ],
                    ),
                    ...payments.take(50).map((payment) {
                      final dateStr = payment.paymentDate.isNotEmpty
                          ? payment.paymentDate
                          : '-';
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${payment.id}', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${payment.accountId}', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              'R\$ ${payment.value.toStringAsFixed(2)}',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        );
      }

      // Salvar e abrir PDF
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'relatorio_banco_dados_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      throw Exception('Erro ao gerar PDF: $e');
    }
  }

  /// Exporta os dados do dashboard com filtros aplicados
  Future<void> exportDashboardToPdf(DashboardExportData data) async {
    try {
      final doc = pw.Document();

      // Separar contas por tipo
      final contasPagar = <Account>[];
      final contasReceber = <Account>[];
      final contasCartoes = <Account>[];

      for (final account in data.accounts) {
        final typeName = data.typeNames[account.typeId]?.toLowerCase() ?? '';
        if (account.cardBrand != null || account.cardBank != null) {
          contasCartoes.add(account);
        } else if (typeName.contains('recebimento')) {
          contasReceber.add(account);
        } else {
          contasPagar.add(account);
        }
      }

      // Página de capa/resumo
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FácilFin',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          'Relatório de Contas',
                          style: const pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          data.periodLabel,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Filtros aplicados
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('Filtro: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(data.filterLabel),
                    pw.SizedBox(width: 20),
                    pw.Text('Contas pagas: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(data.hidePaidAccounts ? 'Ocultas' : 'Visíveis'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Cards de resumo
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildSummaryCard(
                      'A RECEBER',
                      UtilBrasilFields.obterReal(data.totalLancadoReceber),
                      'Previsto: ${UtilBrasilFields.obterReal(data.totalPrevistoReceber)}',
                      PdfColors.green700,
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: _buildSummaryCard(
                      'A PAGAR',
                      UtilBrasilFields.obterReal(data.totalLancadoPagar),
                      'Previsto: ${UtilBrasilFields.obterReal(data.totalPrevistoPagar)}',
                      PdfColors.red700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Saldo
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SALDO PREVISTO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      UtilBrasilFields.obterReal(
                        (data.totalLancadoReceber + data.totalPrevistoReceber) -
                        (data.totalLancadoPagar + data.totalPrevistoPagar),
                      ),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 16,
                        color: (data.totalLancadoReceber + data.totalPrevistoReceber) >=
                               (data.totalLancadoPagar + data.totalPrevistoPagar)
                            ? PdfColors.green700
                            : PdfColors.red700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Resumo de contas
              pw.Text(
                'Resumo',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _tableCell('Categoria', isHeader: true),
                      _tableCell('Qtd', isHeader: true, align: pw.TextAlign.center),
                      _tableCell('Total', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  if (contasReceber.isNotEmpty)
                    pw.TableRow(children: [
                      _tableCell('Recebimentos'),
                      _tableCell('${contasReceber.length}', align: pw.TextAlign.center),
                      _tableCell(
                        UtilBrasilFields.obterReal(contasReceber.fold(0.0, (sum, a) => sum + a.value)),
                        align: pw.TextAlign.right,
                        color: PdfColors.green700,
                      ),
                    ]),
                  if (contasPagar.isNotEmpty)
                    pw.TableRow(children: [
                      _tableCell('Contas a Pagar'),
                      _tableCell('${contasPagar.length}', align: pw.TextAlign.center),
                      _tableCell(
                        UtilBrasilFields.obterReal(contasPagar.fold(0.0, (sum, a) => sum + a.value)),
                        align: pw.TextAlign.right,
                        color: PdfColors.red700,
                      ),
                    ]),
                  if (contasCartoes.isNotEmpty)
                    pw.TableRow(children: [
                      _tableCell('Cartões de Crédito'),
                      _tableCell('${contasCartoes.length}', align: pw.TextAlign.center),
                      _tableCell(
                        UtilBrasilFields.obterReal(contasCartoes.fold(0.0, (sum, a) => sum + a.value)),
                        align: pw.TextAlign.right,
                        color: PdfColors.purple700,
                      ),
                    ]),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _tableCell('TOTAL', isHeader: true),
                      _tableCell('${data.accounts.length}', isHeader: true, align: pw.TextAlign.center),
                      _tableCell(
                        UtilBrasilFields.obterReal(data.accounts.fold(0.0, (sum, a) => sum + a.value)),
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      // Páginas de detalhes das contas
      if (data.accounts.isNotEmpty) {
        final accountsPerPage = 20;
        final totalPages = (data.accounts.length / accountsPerPage).ceil();

        for (int page = 0; page < totalPages; page++) {
          final startIdx = page * accountsPerPage;
          final endIdx = (startIdx + accountsPerPage).clamp(0, data.accounts.length);
          final pageAccounts = data.accounts.sublist(startIdx, endIdx);

          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(40),
              build: (pw.Context context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header da página
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Detalhamento de Contas',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Página ${page + 1} de $totalPages',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),

                  // Tabela de contas
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(0.8), // Data
                      1: const pw.FlexColumnWidth(2.5), // Descrição
                      2: const pw.FlexColumnWidth(1.5), // Tipo/Categoria
                      3: const pw.FlexColumnWidth(1.2), // Valor
                      4: const pw.FlexColumnWidth(0.8), // Status
                    },
                    children: [
                      // Header
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                        children: [
                          _tableCell('Venc.', isHeader: true, fontSize: 9),
                          _tableCell('Descrição', isHeader: true, fontSize: 9),
                          _tableCell('Tipo', isHeader: true, fontSize: 9),
                          _tableCell('Valor', isHeader: true, fontSize: 9, align: pw.TextAlign.right),
                          _tableCell('Status', isHeader: true, fontSize: 9, align: pw.TextAlign.center),
                        ],
                      ),
                      // Dados
                      ...pageAccounts.map((account) {
                        final typeName = data.typeNames[account.typeId] ?? '-';
                        final isRecebimento = typeName.toLowerCase().contains('recebimento');
                        final isCard = account.cardBrand != null;
                        final payment = data.paymentInfo[account.id];
                        final isPaid = payment != null && (payment['isPaid'] as bool? ?? false);

                        String dateStr = '-';
                        if (account.month != null && account.year != null) {
                          dateStr = '${account.dueDay.toString().padLeft(2, '0')}/${account.month.toString().padLeft(2, '0')}';
                        }

                        PdfColor valueColor = PdfColors.grey800;
                        if (isCard) {
                          valueColor = PdfColors.purple700;
                        } else if (isRecebimento) {
                          valueColor = PdfColors.green700;
                        } else {
                          valueColor = PdfColors.red700;
                        }

                        return pw.TableRow(
                          children: [
                            _tableCell(dateStr, fontSize: 9),
                            _tableCell(
                              account.description,
                              fontSize: 9,
                              maxLines: 2,
                            ),
                            _tableCell(
                              isCard ? '${account.cardBank ?? ''} ${account.cardBrand ?? ''}' : typeName,
                              fontSize: 8,
                            ),
                            _tableCell(
                              UtilBrasilFields.obterReal(account.value),
                              fontSize: 9,
                              align: pw.TextAlign.right,
                              color: valueColor,
                            ),
                            _tableCell(
                              isPaid ? 'Pago' : (account.isRecurrent ? 'Recorr.' : 'Pend.'),
                              fontSize: 8,
                              align: pw.TextAlign.center,
                              color: isPaid ? PdfColors.green600 : PdfColors.orange700,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      }

      // Salvar e compartilhar PDF
      final fileName = 'facilfin_${data.filterLabel.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: fileName,
      );
    } catch (e) {
      throw Exception('Erro ao gerar PDF: $e');
    }
  }

  /// Constrói um card de resumo
  pw.Widget _buildSummaryCard(String title, String value, String subtitle, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color.shade(0.3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói uma célula de tabela
  pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    double fontSize = 10,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
    int maxLines = 1,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.grey800,
        ),
        textAlign: align,
        maxLines: maxLines,
      ),
    );
  }
}
