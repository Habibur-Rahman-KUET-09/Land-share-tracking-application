import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/widgets.dart' show Rect;

import '../models/builder_payment.dart';
import '../models/contribution.dart';
import '../models/group_member.dart';
import '../models/land_group.dart';
import '../utils/byte_share.dart';
import '../utils/currency_formatter.dart';
import '../utils/report_range.dart';

/// FR 2.7 "Export করার সুবিধা (PDF/Excel)" — the Excel counterpart of
/// [PdfExportService], same content in spreadsheet form.
class ExcelExportService {
  static const _xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static Future<Uint8List> generate({
    required LandGroup group,
    required List<GroupMember> members,
    required List<Contribution> approvedContributions,
    required List<BuilderPayment> builderPayments,
    required Map<String, String> memberNames,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'রিপোর্ট';
    final sheet = excel[sheetName];
    for (final existing in excel.tables.keys.toList()) {
      if (existing != sheetName) excel.delete(existing);
    }
    excel.setDefaultSheet(sheetName);

    // Only land groups have a location (see PdfExportService for the same).
    sheet.appendRow([
      TextCellValue(group.landLocation.isEmpty ? group.name : '${group.name} — ${group.landLocation}'),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('সদস্য'),
      TextCellValue('মাসিক কিস্তি'),
      TextCellValue('মোট পরিশোধিত'),
      TextCellValue('বাকি'),
    ]);

    double totalCollected = 0;
    for (final m in members.where((m) => m.isActive)) {
      final paid = approvedContributions.where((c) => c.memberId == m.uid).fold<double>(0, (s, c) => s + c.amount);
      totalCollected += paid;
      sheet.appendRow([
        TextCellValue(memberNames[m.uid] ?? m.uid),
        DoubleCellValue(m.monthlyAmount),
        DoubleCellValue(paid),
        DoubleCellValue((m.monthlyAmount - paid).clamp(0, double.infinity)),
      ]);
    }

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('বিল্ডার পেমেন্ট লেজার')]);
    sheet.appendRow([TextCellValue('তারিখ'), TextCellValue('পরিমাণ'), TextCellValue('রেফারেন্স')]);
    double totalRemitted = 0;
    for (final p in builderPayments) {
      totalRemitted += p.amount;
      sheet.appendRow([
        TextCellValue('${p.date.day}-${p.date.month}-${p.date.year}'),
        DoubleCellValue(p.amount),
        TextCellValue(p.referenceNumber ?? '—'),
      ]);
    }

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('সারসংক্ষেপ')]);
    sheet.appendRow([TextCellValue('মোট জমির মূল্য'), DoubleCellValue(group.totalLandValue)]);
    sheet.appendRow([TextCellValue('মোট সংগৃহীত'), DoubleCellValue(totalCollected)]);
    sheet.appendRow([TextCellValue('বিল্ডারকে মোট জমা'), DoubleCellValue(totalRemitted)]);
    sheet.appendRow([TextCellValue('পার্থক্য'), DoubleCellValue(totalCollected - totalRemitted)]);

    return Uint8List.fromList(excel.save()!);
  }

  static Future<void> generateAndShare({
    required LandGroup group,
    required List<GroupMember> members,
    required List<Contribution> approvedContributions,
    required List<BuilderPayment> builderPayments,
    required Map<String, String> memberNames,
    Rect? sharePosition,
  }) async {
    final bytes = await generate(
      group: group,
      members: members,
      approvedContributions: approvedContributions,
      builderPayments: builderPayments,
      memberNames: memberNames,
    );
    await shareBytes(
      bytes: bytes,
      filename: '${group.name} — সাধারণ রিপোর্ট.xlsx',
      mimeType: _xlsxMimeType,
      text: '${group.name} — রিপোর্ট',
      sharePosition: sharePosition,
    );
  }

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Excel counterpart of [PdfExportService]'s monthly matrix — see that
  /// method's doc comment for the layout this mirrors.
  static Future<Uint8List> generateMonthlyMatrix({
    required LandGroup group,
    required List<GroupMember> members,
    required List<Contribution> approvedContributions,
    required List<BuilderPayment> builderPayments,
    required Map<String, String> memberNames,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'ম্যাট্রিক্স রিপোর্ট';
    final sheet = excel[sheetName];
    for (final existing in excel.tables.keys.toList()) {
      if (existing != sheetName) excel.delete(existing);
    }
    excel.setDefaultSheet(sheetName);

    final heading = group.landLocation.isEmpty ? group.name : '${group.name} — ${group.landLocation}';
    sheet.appendRow([TextCellValue('$heading — ম্যাট্রিক্স রিপোর্ট (মাসে মাসে কে কত দিয়েছেন)')]);
    sheet.appendRow([TextCellValue('')]);

    final activeMembers = members.where((m) => m.isActive).toList();
    sheet.appendRow([
      TextCellValue('ক্র.'),
      TextCellValue('মাস'),
      ...activeMembers.map((m) => TextCellValue(memberNames[m.uid] ?? m.uid)),
      TextCellValue('মোট'),
      TextCellValue('রেফারেন্স'),
    ]);

    final months = reportMonths(
      group: group,
      contributions: approvedContributions,
      payments: builderPayments,
    );

    double grandTotal = 0;
    final memberGrandTotals = {for (final m in activeMembers) m.uid: 0.0};

    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final rowContribs = approvedContributions.where((c) => c.year == m.year && c.month == m.month).toList();
      double rowTotal = 0;
      final row = <CellValue>[
        TextCellValue('${i + 1}'),
        TextCellValue('${_monthAbbr[m.month - 1]}-${m.year}'),
      ];
      for (final mem in activeMembers) {
        final amt = rowContribs.where((c) => c.memberId == mem.uid).fold<double>(0, (s, c) => s + c.amount);
        rowTotal += amt;
        memberGrandTotals[mem.uid] = (memberGrandTotals[mem.uid] ?? 0) + amt;
        row.add(DoubleCellValue(amt));
      }
      grandTotal += rowTotal;
      row.add(DoubleCellValue(rowTotal));

      final monthPayments = builderPayments.where((p) => p.date.year == m.year && p.date.month == m.month).toList();
      final remarkText = monthPayments
          .map(
            (p) =>
                'বিল্ডারকে ${CurrencyFormatter.format(p.amount, withSymbol: false)} জমা'
                '${(p.referenceNumber?.isNotEmpty ?? false) ? ' (রেফ: ${p.referenceNumber})' : ''}',
          )
          .join('; ');
      row.add(TextCellValue(remarkText));

      sheet.appendRow(row);
    }

    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('সর্বমোট'),
      ...activeMembers.map((m) => DoubleCellValue(memberGrandTotals[m.uid] ?? 0)),
      DoubleCellValue(grandTotal),
      TextCellValue(''),
    ]);

    return Uint8List.fromList(excel.save()!);
  }

  static Future<void> generateMonthlyMatrixAndShare({
    required LandGroup group,
    required List<GroupMember> members,
    required List<Contribution> approvedContributions,
    required List<BuilderPayment> builderPayments,
    required Map<String, String> memberNames,
    Rect? sharePosition,
  }) async {
    final bytes = await generateMonthlyMatrix(
      group: group,
      members: members,
      approvedContributions: approvedContributions,
      builderPayments: builderPayments,
      memberNames: memberNames,
    );
    await shareBytes(
      bytes: bytes,
      filename: '${group.name} — ম্যাট্রিক্স রিপোর্ট.xlsx',
      mimeType: _xlsxMimeType,
      text: '${group.name} — ম্যাট্রিক্স রিপোর্ট',
      sharePosition: sharePosition,
    );
  }
}
