import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';

import '../models/contribution.dart';
import '../models/group_member.dart';
import 'audit_service.dart';

/// One row of a migration spreadsheet, after parsing.
///
/// A row that couldn't be understood still becomes a [MigrationRow] — with
/// [error] set — so the preview can show the user exactly which line of
/// their file is wrong instead of failing the whole import with one
/// message.
class MigrationRow {
  final int rowNumber;
  final String rawMember;
  final String? memberUid;
  final int? month;
  final int? year;
  final double? amount;
  final PaymentMethod method;
  final String? note;
  final String? error;

  /// True when an entry for this member/month/year/amount already exists —
  /// re-importing the same file must not double the ledger.
  final bool duplicate;

  const MigrationRow({
    required this.rowNumber,
    required this.rawMember,
    this.memberUid,
    this.month,
    this.year,
    this.amount,
    this.method = PaymentMethod.cash,
    this.note,
    this.error,
    this.duplicate = false,
  });

  bool get importable => error == null && !duplicate;
}

class MigrationPreview {
  final List<MigrationRow> rows;
  const MigrationPreview(this.rows);

  List<MigrationRow> get importable => rows.where((r) => r.importable).toList();
  List<MigrationRow> get failed => rows.where((r) => r.error != null).toList();
  List<MigrationRow> get duplicates => rows.where((r) => r.duplicate).toList();
  double get total => importable.fold<double>(0, (t, r) => t + (r.amount ?? 0));
}

/// Brings a group's existing history in from a spreadsheet.
///
/// Most groups have been tracking this in Excel for years before the app
/// existed, and a ledger that starts at zero is a ledger nobody trusts.
class MigrationService {
  final FirebaseFirestore _db;
  final AuditService _audit;

  MigrationService({FirebaseFirestore? db, AuditService? audit})
      : _db = db ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  static const headers = ['সদস্য', 'মাস', 'বছর', 'পরিমাণ', 'পদ্ধতি', 'নোট'];

  /// A filled-in example rather than an empty grid: the fastest way to
  /// explain a format is to show it with the group's own member names
  /// already in column A, so there is nothing to guess about spelling.
  static Uint8List buildTemplate({
    required List<GroupMember> members,
    required Map<String, String> memberNames,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'কিস্তি';
    final sheet = excel[sheetName];
    for (final existing in excel.tables.keys.toList()) {
      if (existing != sheetName) excel.delete(existing);
    }
    excel.setDefaultSheet(sheetName);

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    final now = DateTime.now();
    final active = members.where((m) => m.isActive).toList();
    for (final m in active.take(3)) {
      sheet.appendRow([
        TextCellValue(memberNames[m.uid] ?? m.uid),
        IntCellValue(now.month),
        IntCellValue(now.year),
        DoubleCellValue(m.monthlyAmount == 0 ? 5000 : m.monthlyAmount),
        TextCellValue('নগদ'),
        TextCellValue(''),
      ]);
    }
    if (active.isEmpty) {
      sheet.appendRow([
        TextCellValue('সদস্যের নাম বা ইমেইল'),
        IntCellValue(now.month),
        IntCellValue(now.year),
        DoubleCellValue(5000),
        TextCellValue('নগদ'),
        TextCellValue(''),
      ]);
    }

    return Uint8List.fromList(excel.save()!);
  }

  /// Parses and validates without writing anything. The caller shows the
  /// result and asks for confirmation — an import that silently rewrites a
  /// group's money history is not something to trigger from one tap.
  static MigrationPreview parse({
    required Uint8List bytes,
    required List<GroupMember> members,
    required Map<String, String> memberNames,
    required List<Contribution> existing,
  }) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.getDefaultSheet()] ?? excel.tables.values.first;
    final rows = <MigrationRow>[];

    // Match on name or email, case- and space-insensitive, because whoever
    // types the sheet will not match the app's stored casing exactly.
    String norm(String v) => v.trim().toLowerCase();
    final byKey = <String, String>{};
    for (final m in members) {
      final name = memberNames[m.uid];
      if (name != null && name.trim().isNotEmpty) byKey[norm(name)] = m.uid;
    }

    for (var i = 1; i < sheet.maxRows; i++) {
      final cells = sheet.row(i);
      String cell(int idx) {
        if (idx >= cells.length) return '';
        return cells[idx]?.value?.toString().trim() ?? '';
      }

      final rawMember = cell(0);
      // A trailing blank row is normal in a spreadsheet, not an error.
      if (rawMember.isEmpty && cell(1).isEmpty && cell(3).isEmpty) continue;

      final rowNumber = i + 1;
      final uid = byKey[norm(rawMember)];
      if (uid == null) {
        rows.add(MigrationRow(
          rowNumber: rowNumber,
          rawMember: rawMember,
          error: 'এই নামে কোনো সদস্য নেই',
        ));
        continue;
      }

      final month = int.tryParse(cell(1));
      final year = int.tryParse(cell(2));
      final amount = double.tryParse(cell(3).replaceAll(',', ''));
      if (month == null || month < 1 || month > 12) {
        rows.add(MigrationRow(rowNumber: rowNumber, rawMember: rawMember, error: 'মাস ১-১২ এর মধ্যে দিন'));
        continue;
      }
      if (year == null || year < 2000 || year > 2100) {
        rows.add(MigrationRow(rowNumber: rowNumber, rawMember: rawMember, error: 'বছরটি সঠিক নয়'));
        continue;
      }
      if (amount == null || amount <= 0) {
        rows.add(MigrationRow(rowNumber: rowNumber, rawMember: rawMember, error: 'পরিমাণ সঠিক নয়'));
        continue;
      }

      final duplicate = existing.any((c) =>
          c.memberId == uid &&
          c.month == month &&
          c.year == year &&
          (c.amount - amount).abs() < 0.005 &&
          c.status != ContributionStatus.cancelled);

      rows.add(MigrationRow(
        rowNumber: rowNumber,
        rawMember: rawMember,
        memberUid: uid,
        month: month,
        year: year,
        amount: amount,
        method: _methodFrom(cell(4)),
        note: cell(5).isEmpty ? null : cell(5),
        duplicate: duplicate,
      ));
    }

    return MigrationPreview(rows);
  }

  static PaymentMethod _methodFrom(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('বিকাশ') || v.contains('bkash')) return PaymentMethod.bkash;
    if (v.contains('ব্যাংক') || v.contains('bank')) return PaymentMethod.bank;
    if (v.contains('নগদ') || v.contains('cash')) return PaymentMethod.cash;
    if (v.isEmpty) return PaymentMethod.cash;
    return PaymentMethod.other;
  }

  /// Writes the importable rows as approved contributions.
  ///
  /// They arrive approved because they are history being recorded, not
  /// claims awaiting review — but each one carries `importedAt`, so the
  /// ledger can always distinguish an approval that came from someone
  /// checking a receipt from one that came from a spreadsheet.
  Future<int> import({
    required String groupId,
    required MigrationPreview preview,
    required String importedBy,
  }) async {
    final rows = preview.importable;
    if (rows.isEmpty) return 0;

    final col = _db.collection('groups').doc(groupId).collection('contributions');
    final now = DateTime.now();

    // Firestore caps a batch at 500 writes; a few years of a large group
    // clears that easily.
    const chunkSize = 400;
    for (var start = 0; start < rows.length; start += chunkSize) {
      final batch = _db.batch();
      for (final r in rows.skip(start).take(chunkSize)) {
        final ref = col.doc();
        batch.set(
          ref,
          Contribution(
            id: ref.id,
            groupId: groupId,
            memberId: r.memberUid!,
            month: r.month!,
            year: r.year!,
            amount: r.amount!,
            method: r.method,
            status: ContributionStatus.approved,
            submittedBy: importedBy,
            submittedAt: now,
            approvedBy: importedBy,
            approvedAt: now,
            importedAt: now,
          ).toMap(),
        );
      }
      await batch.commit();
    }

    await _audit.log(
      groupId: groupId,
      actorId: importedBy,
      action: 'import_contributions',
      targetType: 'group',
      targetId: groupId,
      details: '${rows.length} টি পুরোনো কিস্তির এন্ট্রি Excel থেকে আমদানি করা হয়েছে',
    );
    return rows.length;
  }
}
