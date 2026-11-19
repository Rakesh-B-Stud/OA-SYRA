import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../theme/oasyra_colors.dart';
import 'pdf_service.dart';

class OasyraPdfService implements PdfService {
  @override
  Future<Uint8List> generateHealthReport(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/oasyra_brand_purple.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(data['userName'] ?? 'OASYRA User', logoImage),
            pw.SizedBox(height: 24),
            _buildProfileSection(data),
            pw.SizedBox(height: 24),
            _buildAnalysisSection(data),
            pw.SizedBox(height: 24),
            _buildActivitySection(data),
            pw.SizedBox(height: 24),
            _buildHistorySection(data['measurements'] ?? []),
            pw.SizedBox(height: 24),
            _buildPlanSection(data),
            pw.SizedBox(height: 48),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(String name, pw.MemoryImage? logoImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(OasyraColors.primary.toARGB32()),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'OASYRA',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 2.0,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Personal Health Analysis Report',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
          pw.Text(
            'Patient: $name',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProfileSection(Map<String, dynamic> data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'User Profile'),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Age: ${data['age'] ?? "N/A"}'),
                pw.Text('Gender: ${data['gender'] ?? "N/A"}'),
                pw.Text('Height: ${data['height'] ?? "N/A"} cm'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Current Weight: ${data['weight'] ?? "N/A"} kg'),
                pw.Text('Target Weight: ${data['targetWeight'] ?? "N/A"} kg'),
                pw.Text('Activity: ${data['activityLevel'] ?? "N/A"}'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text('Preferences: ${data['cuisine'] ?? "N/A"}, ${data['dietType'] ?? "N/A"}'),
        pw.Text('Goals: ${data['goals'] ?? "N/A"}'),
      ],
    );
  }

  pw.Widget _buildAnalysisSection(Map<String, dynamic> data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Obesity Risk & Metabolic Analysis'),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildDataCard('BMI', data['bmi'] ?? "N/A", data['bmiCategory'] ?? ""),
            _buildDataCard('BMR', '${data['bmr'] ?? "N/A"} kcal', 'Basal Metabolic Rate'),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildDataCard('Daily Needs', '${data['dailyEnergy'] ?? "N/A"} kcal', 'Estimated Expenditure'),
            _buildDataCard('Risk Level', data['overallConcern'] ?? "UNKNOWN", 'Screening Indicator'),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('Behavioral Insights:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ...(data['behavioralFactors'] as List<dynamic>? ?? []).map((f) => pw.Bullet(text: '${f['name']}: ${f['interpretation']}')),
        pw.SizedBox(height: 12),
        pw.Text('Personalized Recommendations:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ...(data['recommendations'] as List<dynamic>? ?? []).map((r) => pw.Bullet(text: r.toString())),
      ],
    );
  }

  pw.Widget _buildActivitySection(Map<String, dynamic> data) {
    if (data['todaySteps'] == null) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Real-World Activity (Latest Sync)'),
        pw.Text('Data Source: Android Health Connect (Fitbit)', style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Steps Today: ${data['todaySteps']}'),
            pw.Text('Calories Burned: ${data['todayCaloriesBurned']} kcal'),
          ],
        ),
        pw.Text('Last Sync: ${data['lastSync'] ?? "N/A"}'),
      ],
    );
  }

  pw.Widget _buildHistorySection(List<dynamic> measurements) {
    if (measurements.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Header(level: 1, text: 'Progress Trends'),
          pw.Text('Insufficient historical data for trend analysis.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Measurement History'),
        pw.TableHelper.fromTextArray(
          context: null,
          data: <List<String>>[
            <String>['Date', 'Weight (kg)', 'BMI'],
            ...measurements.map((m) => [
                  m['date'] as String,
                  m['weight'] as String,
                  m['bmi'] as String,
            ]),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPlanSection(Map<String, dynamic> data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, text: 'Personalized Health Plan'),
        pw.Text('Action Plan:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ...(data['personalizedPlan'] as List<dynamic>? ?? []).map((p) => pw.Bullet(text: '[${p['domain']}] ${p['goal']}: ${p['action']}')),
        pw.SizedBox(height: 12),
        pw.Text('Nutrition Strategy:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ...(data['nutritionPlan'] as List<dynamic>? ?? []).map((n) => pw.Bullet(text: '${n['type']}: ${n['dish']} (${n['portion']})')),
      ],
    );
  }

  pw.Widget _buildDataCard(String label, String value, String sub) {
    return pw.Container(
      width: 200,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(sub, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Text(
          'MEDICAL DISCLAIMER: This report is for informational purposes only and does not constitute medical advice or diagnosis. Please consult a healthcare professional for clinical concerns.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }
}
