import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Configuração para exportação visual de PDF
class VisualPdfExportConfig {
  /// Formato da página (default: A4 portrait)
  final PdfPageFormat pageFormat;

  /// Margem das páginas em pontos
  final double pageMargin;

  /// Pixel ratio para captura (maior = melhor qualidade)
  final double pixelRatio;

  /// Largura fixa do widget de exportação (em pixels lógicos)
  final double exportWidgetWidth;

  /// Se deve adicionar rodapé com data/hora
  final bool showFooter;

  /// Texto customizado do rodapé (substitui o padrão)
  final String? footerText;

  const VisualPdfExportConfig({
    this.pageFormat = PdfPageFormat.a4,
    this.pageMargin = 14,
    this.pixelRatio = 3.0,
    this.exportWidgetWidth = 595, // Largura A4 em pontos
    this.showFooter = true,
    this.footerText,
  });

  /// Config padrão para Windows (alta qualidade)
  static const windows = VisualPdfExportConfig(
    pixelRatio: 3.0,
    pageMargin: 14,
  );

  /// Config para mobile (qualidade moderada para performance)
  static const mobile = VisualPdfExportConfig(
    pixelRatio: 2.0,
    pageMargin: 12,
  );

  /// Altura útil da página (descontando margens e rodapé)
  double get usablePageHeight {
    final totalMargin = pageMargin * 2;
    final footerHeight = showFooter ? 20.0 : 0.0;
    return pageFormat.availableHeight - totalMargin - footerHeight;
  }

  /// Largura útil da página
  double get usablePageWidth {
    return pageFormat.availableWidth - (pageMargin * 2);
  }
}

/// Resultado da captura de widget
class WidgetCaptureResult {
  /// Imagem completa capturada
  final Uint8List imageBytes;

  /// Largura da imagem em pixels
  final int width;

  /// Altura da imagem em pixels
  final int height;

  const WidgetCaptureResult({
    required this.imageBytes,
    required this.width,
    required this.height,
  });
}

/// Callback para progresso da exportação
typedef ExportProgressCallback = void Function(double progress, String stage);

/// Serviço para exportação visual de PDF.
///
/// Captura widgets Flutter como imagens e gera PDFs multi-página
/// que reproduzem exatamente o layout visual do app.
class VisualPdfExportService {
  static final VisualPdfExportService instance = VisualPdfExportService._();

  VisualPdfExportService._();

  /// Exporta um widget para PDF capturando-o como imagem.
  ///
  /// O widget é renderizado offscreen em tamanho completo (sem scroll),
  /// capturado como imagem, fatiado em páginas A4 e exportado como PDF.
  Future<void> exportWidgetToPdf({
    required BuildContext context,
    required Widget Function(BuildContext context) widgetBuilder,
    required String fileBaseName,
    VisualPdfExportConfig config = const VisualPdfExportConfig(),
    ExportProgressCallback? onProgress,
  }) async {
    onProgress?.call(0.1, 'Preparando exportação...');

    // 1. Capturar widget como imagem
    onProgress?.call(0.2, 'Renderizando layout...');
    final captureResult = await _captureWidgetAsImage(
      context: context,
      widgetBuilder: widgetBuilder,
      config: config,
    );

    // 2. Fatiar imagem em páginas
    onProgress?.call(0.5, 'Processando páginas...');
    final slices = await _sliceImageIntoPages(
      captureResult: captureResult,
      config: config,
    );

    // 3. Criar PDF com as fatias
    onProgress?.call(0.7, 'Gerando PDF...');
    final pdfBytes = await _buildPdfFromSlices(
      slices: slices,
      config: config,
    );

    // 4. Compartilhar/salvar PDF
    onProgress?.call(0.9, 'Salvando arquivo...');
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${fileBaseName}_$timestamp.pdf';

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _saveToFile(pdfBytes, fileName);
    } else {
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    }

    onProgress?.call(1.0, 'Concluído!');
  }

  /// Captura um widget como imagem PNG.
  Future<WidgetCaptureResult> _captureWidgetAsImage({
    required BuildContext context,
    required Widget Function(BuildContext context) widgetBuilder,
    required VisualPdfExportConfig config,
  }) async {
    // Criar uma chave global para o RepaintBoundary
    final boundaryKey = GlobalKey();

    // Criar o widget de exportação envolvido em RepaintBoundary
    final exportWidget = RepaintBoundary(
      key: boundaryKey,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: Size(config.exportWidgetWidth, double.infinity),
          ),
          child: SizedBox(
            width: config.exportWidgetWidth,
            child: widgetBuilder(context),
          ),
        ),
      ),
    );

    // Renderizar offscreen usando um overlay temporário
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000, // Fora da tela
        top: -10000,
        child: exportWidget,
      ),
    );

    final overlay = Overlay.of(context);
    overlay.insert(overlayEntry);

    // Aguardar o próximo frame para garantir que o widget foi renderizado
    await Future.delayed(const Duration(milliseconds: 100));
    await WidgetsBinding.instance.endOfFrame;

    try {
      // Obter o RenderRepaintBoundary
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Não foi possível capturar o widget: boundary não encontrado');
      }

      // Capturar como imagem
      final image = await boundary.toImage(pixelRatio: config.pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Não foi possível converter imagem para bytes');
      }

      return WidgetCaptureResult(
        imageBytes: byteData.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
    } finally {
      // Remover o overlay
      overlayEntry.remove();
    }
  }

  /// Fatia uma imagem capturada em páginas A4.
  Future<List<Uint8List>> _sliceImageIntoPages({
    required WidgetCaptureResult captureResult,
    required VisualPdfExportConfig config,
  }) async {
    // Decodificar a imagem PNG
    final decodedImage = img.decodePng(captureResult.imageBytes);
    if (decodedImage == null) {
      throw Exception('Não foi possível decodificar a imagem');
    }

    final imageWidth = decodedImage.width;
    final imageHeight = decodedImage.height;

    // Calcular altura de cada fatia em pixels
    // Considerar o pixel ratio usado na captura
    final pageHeightInPixels = (config.usablePageHeight * config.pixelRatio).round();

    // Calcular número de páginas necessárias
    final numPages = (imageHeight / pageHeightInPixels).ceil();

    final slices = <Uint8List>[];

    for (int page = 0; page < numPages; page++) {
      final startY = page * pageHeightInPixels;
      final remainingHeight = imageHeight - startY;
      final sliceHeight = remainingHeight < pageHeightInPixels ? remainingHeight : pageHeightInPixels;

      // Recortar a fatia
      final slice = img.copyCrop(
        decodedImage,
        x: 0,
        y: startY,
        width: imageWidth,
        height: sliceHeight,
      );

      // Converter para PNG
      final pngBytes = img.encodePng(slice);
      slices.add(Uint8List.fromList(pngBytes));
    }

    debugPrint('📄 [VisualPdfExport] Imagem fatiada em $numPages página(s)');
    return slices;
  }

  /// Constrói o PDF a partir das fatias de imagem.
  Future<Uint8List> _buildPdfFromSlices({
    required List<Uint8List> slices,
    required VisualPdfExportConfig config,
  }) async {
    final doc = pw.Document();
    final pageMargin = pw.EdgeInsets.all(config.pageMargin);
    final timestamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final footerText = config.footerText ?? 'FácilFin · gerado em $timestamp';

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];

      doc.addPage(
        pw.Page(
          pageFormat: config.pageFormat,
          margin: pageMargin,
          build: (context) {
            return pw.Column(
              children: [
                // Imagem centralizada
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(slice),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
                // Rodapé opcional
                if (config.showFooter) ...[
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        footerText,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.Text(
                        'Página ${i + 1} de ${slices.length}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }

  /// Salva o PDF em arquivo (para desktop).
  Future<void> _saveToFile(Uint8List pdfBytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final facilfinDir = Directory('${directory.path}/FacilFin/Relatorios');

      if (!await facilfinDir.exists()) {
        await facilfinDir.create(recursive: true);
      }

      final filePath = '${facilfinDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      debugPrint('📁 [VisualPdfExport] PDF salvo em: $filePath');

      // Tentar abrir o arquivo no sistema
      if (Platform.isWindows) {
        await Process.run('explorer', [filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
      }
    } catch (e) {
      debugPrint('❌ [VisualPdfExport] Erro ao salvar arquivo: $e');
      // Fallback: usar Printing.sharePdf
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    }
  }

  /// Calcula quantas páginas serão necessárias para uma altura total.
  int calculatePageCount({
    required double totalHeight,
    required VisualPdfExportConfig config,
  }) {
    return (totalHeight / config.usablePageHeight).ceil();
  }

  /// Exporta diretamente de uma lista de slices pré-processados.
  Future<Uint8List> buildPdfFromSlices(
    List<Uint8List> slices, {
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    double margin = 14,
    bool showFooter = true,
    String? footerText,
  }) async {
    final config = VisualPdfExportConfig(
      pageFormat: pageFormat,
      pageMargin: margin,
      showFooter: showFooter,
      footerText: footerText,
    );

    return _buildPdfFromSlices(slices: slices, config: config);
  }
}
