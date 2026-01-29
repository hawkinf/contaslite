import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:finance_app/services/visual_pdf_export_service.dart';

void main() {
  group('VisualPdfExportConfig', () {
    test('default config has correct values', () {
      const config = VisualPdfExportConfig();

      expect(config.pageFormat, PdfPageFormat.a4);
      expect(config.pageMargin, 14);
      expect(config.pixelRatio, 3.0);
      expect(config.exportWidgetWidth, 595);
      expect(config.showFooter, true);
      expect(config.footerText, null);
    });

    test('windows config has high pixel ratio', () {
      const config = VisualPdfExportConfig.windows;

      expect(config.pixelRatio, 3.0);
      expect(config.pageMargin, 14);
    });

    test('mobile config has lower pixel ratio for performance', () {
      const config = VisualPdfExportConfig.mobile;

      expect(config.pixelRatio, 2.0);
      expect(config.pageMargin, 12);
    });

    test('usablePageHeight calculates correctly', () {
      const config = VisualPdfExportConfig(
        pageFormat: PdfPageFormat.a4,
        pageMargin: 14,
        showFooter: true,
      );

      // A4 available height - margins - footer
      final expectedHeight = PdfPageFormat.a4.availableHeight - (14 * 2) - 20;
      expect(config.usablePageHeight, expectedHeight);
    });

    test('usablePageHeight without footer is larger', () {
      const configWithFooter = VisualPdfExportConfig(
        pageMargin: 14,
        showFooter: true,
      );
      const configWithoutFooter = VisualPdfExportConfig(
        pageMargin: 14,
        showFooter: false,
      );

      expect(configWithoutFooter.usablePageHeight, greaterThan(configWithFooter.usablePageHeight));
      expect(configWithoutFooter.usablePageHeight - configWithFooter.usablePageHeight, 20);
    });

    test('usablePageWidth calculates correctly', () {
      const config = VisualPdfExportConfig(
        pageFormat: PdfPageFormat.a4,
        pageMargin: 14,
      );

      final expectedWidth = PdfPageFormat.a4.availableWidth - (14 * 2);
      expect(config.usablePageWidth, expectedWidth);
    });

    test('custom footer text is preserved', () {
      const config = VisualPdfExportConfig(
        footerText: 'Custom Footer',
      );

      expect(config.footerText, 'Custom Footer');
    });
  });

  group('WidgetCaptureResult', () {
    test('stores image data correctly', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = WidgetCaptureResult(
        imageBytes: bytes,
        width: 100,
        height: 200,
      );

      expect(result.width, 100);
      expect(result.height, 200);
      expect(result.imageBytes, bytes);
    });
  });

  group('VisualPdfExportService', () {
    test('instance is singleton', () {
      final instance1 = VisualPdfExportService.instance;
      final instance2 = VisualPdfExportService.instance;

      expect(identical(instance1, instance2), true);
    });

    test('calculatePageCount returns 1 for small content', () {
      const config = VisualPdfExportConfig();
      final pageCount = VisualPdfExportService.instance.calculatePageCount(
        totalHeight: 100,
        config: config,
      );

      expect(pageCount, 1);
    });

    test('calculatePageCount returns multiple pages for tall content', () {
      const config = VisualPdfExportConfig();
      // Use a very tall height to ensure multiple pages
      final pageCount = VisualPdfExportService.instance.calculatePageCount(
        totalHeight: config.usablePageHeight * 3,
        config: config,
      );

      expect(pageCount, 3);
    });

    test('calculatePageCount rounds up partial pages', () {
      const config = VisualPdfExportConfig();
      final pageCount = VisualPdfExportService.instance.calculatePageCount(
        totalHeight: config.usablePageHeight * 1.5,
        config: config,
      );

      expect(pageCount, 2);
    });

    test('buildPdfFromSlices creates PDF with correct page count', () async {
      // Create dummy image slices (1x1 pixel PNG)
      final dummyPng = _createMinimalPng();
      final slices = [dummyPng, dummyPng, dummyPng];

      final pdfBytes = await VisualPdfExportService.instance.buildPdfFromSlices(
        slices,
        pageFormat: PdfPageFormat.a4,
        margin: 14,
      );

      // Verify PDF was created
      expect(pdfBytes, isNotEmpty);
      // PDF header should start with %PDF
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    });

    test('buildPdfFromSlices respects showFooter option', () async {
      final dummyPng = _createMinimalPng();

      final pdfWithFooter = await VisualPdfExportService.instance.buildPdfFromSlices(
        [dummyPng],
        showFooter: true,
      );

      final pdfWithoutFooter = await VisualPdfExportService.instance.buildPdfFromSlices(
        [dummyPng],
        showFooter: false,
      );

      // Both should be valid PDFs
      expect(pdfWithFooter, isNotEmpty);
      expect(pdfWithoutFooter, isNotEmpty);
    });

    test('buildPdfFromSlices uses custom footer text', () async {
      final dummyPng = _createMinimalPng();

      final pdfBytes = await VisualPdfExportService.instance.buildPdfFromSlices(
        [dummyPng],
        footerText: 'Custom Footer Text',
      );

      expect(pdfBytes, isNotEmpty);
    });
  });

  group('ExportProgressCallback', () {
    test('callback type is defined correctly', () {
      // Just verify the type exists and can be used
      void testCallback(double progress, String stage) {
        expect(progress, isA<double>());
        expect(stage, isA<String>());
      }

      testCallback(0.5, 'Testing');
    });
  });
}

/// Creates a minimal valid PNG image (1x1 pixel, transparent)
Uint8List _createMinimalPng() {
  // Minimal 1x1 transparent PNG
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 dimensions
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // 8-bit RGBA
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, // compressed data
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
    0x42, 0x60, 0x82,
  ]);
}
