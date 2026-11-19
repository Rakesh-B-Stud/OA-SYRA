import 'dart:typed_data';

abstract class PdfService {
  /// Generates a branded health report PDF.
  Future<Uint8List> generateHealthReport(Map<String, dynamic> data);
}
