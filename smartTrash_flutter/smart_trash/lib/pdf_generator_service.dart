import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfGeneratorService {
  // --- Executive Studio Palette ---
  static const _kDeepForest = PdfColor.fromInt(0xFF1E3A24);
  static const _kSable      = PdfColor.fromInt(0xFFFDFCF9);
  static const _kSage       = PdfColor.fromInt(0xFFA7B9A9);
  static const _kError      = PdfColor.fromInt(0xFF991B1B);
  static const _kAlert      = PdfColor.fromInt(0xFFB45309);

  static Future<void> generateAndDownloadReport({
    required String reportText,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final reportId = "IDX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    // Header Widget
    pw.Widget buildHeader() {
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 20),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _kDeepForest, width: 2)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("SMARTTRASH AI",
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: _kDeepForest)),
                pw.Text("Système de Gestion de Déchets Intelligent",
                    style: const pw.TextStyle(fontSize: 10, color: _kSage)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("RAPPORT D'ANALYSE IA",
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _kDeepForest)),
                pw.Text("N° $reportId",
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text("Date: $dateStr",
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      );
    }

    // Body content parsing
    List<pw.Widget> buildReportLines() {
      final lines = reportText.split('\n');
      List<pw.Widget> widgets = [];

      for (var line in lines) {
        if (line.trim().isEmpty) continue;

        PdfColor color = _kDeepForest;
        pw.FontWeight weight = pw.FontWeight.normal;
        pw.Widget? iconBlob;

        if (line.contains('anomalies détectées') || line.contains('Anomalie détectée')) {
          color = _kError;
          weight = pw.FontWeight.bold;
          iconBlob = pw.Container(width: 5, height: 15, color: _kError);
        } else if (line.contains('Action prioritaire') || line.contains('Suggestion')) {
          color = _kAlert;
          weight = pw.FontWeight.bold;
        }

        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (iconBlob != null)
                  pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 10),
                      child: iconBlob),
                pw.Expanded(
                  child: pw.Text(
                    line,
                    style: pw.TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: weight,
                      lineSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return widgets;
    }

    // Signature Widget
    pw.Widget buildSignature() {
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 50),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor(_kDeepForest.red, _kDeepForest.green, _kDeepForest.blue, 0.3), width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                children: [
                  pw.Text("VALIDE PAR IA", style: pw.TextStyle(fontSize: 8, color: PdfColor(_kDeepForest.red, _kDeepForest.green, _kDeepForest.blue, 0.5))),
                  pw.Text("SMARTTRASH-CERTIFIED", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kDeepForest)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 150,
                  height: 40,
                  child: pw.Text("AI Expert Signature", 
                    style: pw.TextStyle(
                      color: PdfColors.blue800, 
                      fontSize: 20, 
                      fontStyle: pw.FontStyle.italic, 
                      fontWeight: pw.FontWeight.bold
                    )
                  ),
                ),
                pw.Container(
                  width: 150,
                  child: pw.Divider(color: _kDeepForest, thickness: 1),
                ),
                pw.Text("Directeur de l'Intelligence Artificielle", style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            buildHeader(),
            pw.SizedBox(height: 30),
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: const pw.BoxDecoration(
                color: _kSable,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("RÉSUMÉ EXÉCUTIF DU DIAGNOSTIC",
                      style: pw.TextStyle(
                          color: _kDeepForest,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  ...buildReportLines(),
                ],
              ),
            ),
            buildSignature(),
          ];
        },
      ),
    );

    // Save and download (or print preview)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapport_SmartTrash_$reportId.pdf',
    );
  }
}
