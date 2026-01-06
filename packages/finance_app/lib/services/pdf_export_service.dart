import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/db_helper.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  static final PdfExportService instance = PdfExportService._init();

  PdfExportService._init();

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
                pw.Text('• Formas de Pagamento: ${paymentMethods.length}'),
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

  // Método auxiliar para obter todos os pagamentos (pode não existir)
  // Adicionaremos isso no db_helper.dart
}
