import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/builder_payment.dart';
import '../models/contribution.dart';
import '../models/group_member.dart';
import '../models/land_group.dart';

/// FR 2.7 "Export করার সুবিধা (PDF/Excel)" — the Excel counterpart of
/// [PdfExportService], same content in spreadsheet form.
class ExcelExportService {
  static Future<File> generate({
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

    sheet.appendRow([TextCellValue('${group.name} — ${group.landLocation}')]);
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

    final bytes = excel.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${group.name} — রিপোর্ট.xlsx');
    await file.writeAsBytes(bytes!, flush: true);
    return file;
  }

  static Future<void> generateAndShare({
    required LandGroup group,
    required List<GroupMember> members,
    required List<Contribution> approvedContributions,
    required List<BuilderPayment> builderPayments,
    required Map<String, String> memberNames,
  }) async {
    final file = await generate(
      group: group,
      members: members,
      approvedContributions: approvedContributions,
      builderPayments: builderPayments,
      memberNames: memberNames,
    );
    await Share.shareXFiles([XFile(file.path)], text: '${group.name} — রিপোর্ট');
  }
}
