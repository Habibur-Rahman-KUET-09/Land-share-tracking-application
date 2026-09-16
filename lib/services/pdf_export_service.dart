import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/builder_payment.dart';
import '../models/contribution.dart';
import '../models/group_member.dart';
import '../models/land_group.dart';
import '../utils/bangla_pdf_text.dart';
import '../utils/currency_formatter.dart';

/// FR 2.7 "Export/Share Statement (PDF)" — a group's full report: per-member
/// summary + builder payment ledger. Bangla labels are rasterized through
/// [BanglaPdfText] (see that class for why — package:pdf's own text layout
/// doesn't shape Bengali pre-base vowel signs correctly); amounts stay as
/// native selectable text since digits never need reordering.
class PdfExportService {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _ensureFonts() async {
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansBengali-Regular.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansBengali-Bold.ttf'));
  }

  static Future<pw.Document> _buildDocument({
    required LandGroup group,
    required List<GroupMember> members,
    required List<Contribution> approvedContributions,
    required List<BuilderPayment> builderPayments,
    required Map<String, String> memberNames,
  }) async {
    await _ensureFonts();
    final doc = pw.Document();
    final numberStyle = pw.TextStyle(fontSize: 10, font: _regular);
    final totalStyle = pw.TextStyle(fontSize: 10, font: _bold, fontWeight: pw.FontWeight.bold);

    Future<pw.Widget> label(String text, {double fontSize = 10, bool bold = false}) {
      return BanglaPdfText.widget(text, fontSize: fontSize, bold: bold);
    }

    pw.Widget cell(pw.Widget child, {pw.Alignment alignment = pw.Alignment.centerLeft}) {
      return pw.Container(
        alignment: alignment,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: child,
      );
    }

    final subtitle = await label('${group.name} — ${group.landLocation}', fontSize: 16, bold: true);

    final memberHeaderRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        cell(await label('সদস্য', bold: true)),
        cell(await label('মাসিক কিস্তি', bold: true)),
        cell(await label('মোট পরিশোধিত', bold: true)),
        cell(await label('বাকি', bold: true)),
      ],
    );

    final memberRows = <pw.TableRow>[];
    double totalCollected = 0;
    for (final m in members.where((m) => m.isActive)) {
      final paid = approvedContributions.where((c) => c.memberId == m.uid).fold<double>(0, (s, c) => s + c.amount);
      totalCollected += paid;
      memberRows.add(
        pw.TableRow(
          children: [
            cell(await label(memberNames[m.uid] ?? m.uid)),
            cell(pw.Text(CurrencyFormatter.format(m.monthlyAmount, withSymbol: false), style: numberStyle),
                alignment: pw.Alignment.centerRight),
            cell(pw.Text(CurrencyFormatter.format(paid, withSymbol: false), style: numberStyle),
                alignment: pw.Alignment.centerRight),
            cell(
              pw.Text(
                CurrencyFormatter.format((m.monthlyAmount - paid).clamp(0, double.infinity), withSymbol: false),
                style: numberStyle,
              ),
              alignment: pw.Alignment.centerRight,
            ),
          ],
        ),
      );
    }

    final builderHeading = await label('বিল্ডার পেমেন্ট লেজার', fontSize: 13, bold: true);
    final builderHeaderRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        cell(await label('তারিখ', bold: true)),
        cell(await label('পরিমাণ', bold: true)),
        cell(await label('রেফারেন্স', bold: true)),
      ],
    );
    final builderRows = <pw.TableRow>[];
    double totalRemitted = 0;
    for (final p in builderPayments) {
      totalRemitted += p.amount;
      builderRows.add(
        pw.TableRow(
          children: [
            cell(pw.Text('${p.date.day}-${p.date.month}-${p.date.year}', style: numberStyle)),
            cell(pw.Text(CurrencyFormatter.format(p.amount, withSymbol: false), style: numberStyle),
                alignment: pw.Alignment.centerRight),
            cell(await label(p.referenceNumber ?? '—')),
          ],
        ),
      );
    }

    final summaryHeading = await label('সারসংক্ষেপ', fontSize: 13, bold: true);
    final summaryLabels = await Future.wait([
      label('মোট জমির মূল্য'),
      label('মোট সংগৃহীত'),
      label('বিল্ডারকে মোট জমা'),
      label('পার্থক্য', bold: true),
    ]);

    pw.Widget summaryRow(pw.Widget labelWidget, double amount, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            labelWidget,
            pw.Text(CurrencyFormatter.format(amount, withSymbol: false), style: bold ? totalStyle : numberStyle),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          subtitle,
          pw.SizedBox(height: 16),
          summaryHeading,
          pw.SizedBox(height: 8),
          summaryRow(summaryLabels[0], group.totalLandValue),
          summaryRow(summaryLabels[1], totalCollected),
          summaryRow(summaryLabels[2], totalRemitted),
          pw.Divider(color: PdfColors.grey400, height: 12),
          summaryRow(summaryLabels[3], totalCollected - totalRemitted, bold: true),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [memberHeaderRow, ...memberRows],
          ),
          pw.SizedBox(height: 20),
          builderHeading,
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [builderHeaderRow, ...builderRows],
          ),
        ],
      ),
    );

    return doc;
  }

  static Future<void> generateAndShare({
    required LandGroup group,
    required List<GroupMember> members,
    required List<Contribution> approvedContributions,
    required List<BuilderPayment> builderPayments,
    required Map<String, String> memberNames,
  }) async {
    final doc = await _buildDocument(
      group: group,
      members: members,
      approvedContributions: approvedContributions,
      builderPayments: builderPayments,
      memberNames: memberNames,
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${group.name} — রিপোর্ট.pdf',
    );
  }
}
