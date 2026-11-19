import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/theme/oasyra_colors.dart';
import '../../../../shared/widgets/premium_components.dart';

class ReportPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const ReportPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OasyraColors.background,
      body: Column(
        children: [
          PremiumPageHeader(
            title: 'Report Preview',
            subtitle: fileName,
            showBackButton: true,
          ),
          Expanded(
            child: PdfPreview(
              build: (format) => pdfBytes,
              useActions: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              loadingWidget: const Center(child: CircularProgressIndicator()),
              pdfFileName: fileName,
            ),
          ),
        ],
      ),
    );
  }
}
