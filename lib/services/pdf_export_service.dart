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

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// One row per calendar month from the group's creation to now, one
  /// column per active member showing their approved contributions that
  /// month, a Total column, and a Remark column auto-filled from that
  /// month's recorded builder payments — matches the owner's own tracking
  /// spreadsheet layout, minus the down-payment/installment split (kept as
  /// a single running total, per their own call on that distinction).
  static Future<pw.Document> _buildMonthlyMatrixDocument({
    required LandGroup group,
    required List<GroupMember> members,
    required List<Contribution> approvedContributions,
    required List<BuilderPayment> builderPayments,
    required Map<String, String> memberNames,
  }) async {
    await _ensureFonts();
    final doc = pw.Document();
    final numberStyle = pw.TextStyle(fontSize: 8.5, font: _regular);
    final totalStyle = pw.TextStyle(fontSize: 8.5, font: _bold, fontWeight: pw.FontWeight.bold);

    Future<pw.Widget> label(String text, {double fontSize = 8.5, bool bold = false}) {
      return BanglaPdfText.widget(text, fontSize: fontSize, bold: bold);
    }

    pw.Widget cell(pw.Widget child, {pw.Alignment alignment = pw.Alignment.centerLeft}) {
      return pw.Container(
        alignment: alignment,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: child,
      );
    }

    final activeMembers = members.where((m) => m.isActive).toList();
    final subtitle = await label(
      '${group.name} — ${group.landLocation} — মাসভিত্তিক পেমেন্ট ম্যাট্রিক্স',
      fontSize: 14,
      bold: true,
    );

    final months = <DateTime>[];
    var cur = DateTime(group.createdAt.year, group.createdAt.month);
    final lastMonth = DateTime(DateTime.now().year, DateTime.now().month);
    while (!cur.isAfter(lastMonth)) {
      months.add(cur);
      cur = DateTime(cur.year, cur.month + 1);
    }

    final headerCells = <pw.Widget>[
      cell(await label('ক্র.', bold: true)),
      cell(await label('মাস', bold: true)),
    ];
    for (final m in activeMembers) {
      headerCells.add(cell(await label(memberNames[m.uid] ?? m.uid, bold: true), alignment: pw.Alignment.center));
    }
    headerCells.add(cell(await label('মোট', bold: true), alignment: pw.Alignment.center));
    headerCells.add(cell(await label('রেফারেন্স', bold: true)));
    final headerRow = pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey300), children: headerCells);

    final rows = <pw.TableRow>[];
    double grandTotal = 0;
    final memberGrandTotals = {for (final m in activeMembers) m.uid: 0.0};

    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final rowContribs = approvedContributions.where((c) => c.year == m.year && c.month == m.month).toList();
      double rowTotal = 0;
      final cells = <pw.Widget>[
        cell(pw.Text('${i + 1}', style: numberStyle)),
        cell(pw.Text('${_monthAbbr[m.month - 1]}-${m.year}', style: numberStyle)),
      ];
      for (final mem in activeMembers) {
        final amt = rowContribs.where((c) => c.memberId == mem.uid).fold<double>(0, (s, c) => s + c.amount);
        rowTotal += amt;
        memberGrandTotals[mem.uid] = (memberGrandTotals[mem.uid] ?? 0) + amt;
        cells.add(
          cell(
            pw.Text(amt == 0 ? '-' : CurrencyFormatter.format(amt, withSymbol: false), style: numberStyle),
            alignment: pw.Alignment.centerRight,
          ),
        );
      }
      grandTotal += rowTotal;
      cells.add(
        cell(
          pw.Text(rowTotal == 0 ? '-' : CurrencyFormatter.format(rowTotal, withSymbol: false), style: totalStyle),
          alignment: pw.Alignment.centerRight,
        ),
      );

      final monthPayments = builderPayments.where((p) => p.date.year == m.year && p.date.month == m.month).toList();
      final remarkText = monthPayments
          .map(
            (p) =>
                'বিল্ডারকে ${CurrencyFormatter.format(p.amount, withSymbol: false)} জমা'
                '${(p.referenceNumber?.isNotEmpty ?? false) ? ' (রেফ: ${p.referenceNumber})' : ''}',
          )
          .join('; ');
      cells.add(cell(await label(remarkText)));

      rows.add(pw.TableRow(children: cells));
    }

    final totalCells = <pw.Widget>[cell(pw.SizedBox()), cell(await label('সর্বমোট', bold: true))];
    for (final mem in activeMembers) {
      totalCells.add(
        cell(
          pw.Text(CurrencyFormatter.format(memberGrandTotals[mem.uid] ?? 0, withSymbol: false), style: totalStyle),
          alignment: pw.Alignment.centerRight,
        ),
      );
    }
    totalCells.add(
      cell(
        pw.Text(CurrencyFormatter.format(grandTotal, withSymbol: false), style: totalStyle),
        alignment: pw.Alignment.centerRight,
      ),
    );
    totalCells.add(cell(pw.SizedBox()));
    final totalRow = pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: totalCells);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          subtitle,
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FixedColumnWidth(52),
              for (var i = 0; i < activeMembers.length; i++) 2 + i: const pw.FlexColumnWidth(1),
              2 + activeMembers.length: const pw.FlexColumnWidth(1.2),
              3 + activeMembers.length: const pw.FlexColumnWidth(2.5),
            },
            children: [headerRow, ...rows, totalRow],
          ),
        ],
      ),
    );

    return doc;
  }

  static Future<void> generateMonthlyMatrixAndShare({
    required LandGroup group,
    required List<GroupMember> members,
    required List<Contribution> approvedContributions,
    required List<BuilderPayment> builderPayments,
    required Map<String, String> memberNames,
  }) async {
    final doc = await _buildMonthlyMatrixDocument(
      group: group,
      members: members,
      approvedContributions: approvedContributions,
      builderPayments: builderPayments,
      memberNames: memberNames,
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${group.name} — মাসভিত্তিক রিপোর্ট.pdf',
    );
  }
}
