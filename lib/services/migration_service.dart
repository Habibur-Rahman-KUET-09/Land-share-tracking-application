import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';

import '../models/builder_payment.dart';
import '../models/contribution.dart';
import '../models/group_member.dart';
import '../models/land_group.dart';
import '../utils/xlsx_reader.dart';
import 'audit_service.dart';

/// Which side of the ledger a spreadsheet row belongs to.
///
/// A group's history is money in (members' instalments) and money out (what
/// was remitted to the builder, or deposited to the bank in a savings
/// group). Both live in the same file so a group migrates once, from one
/// sheet, instead of juggling two.
enum MigrationKind { contribution, payment }

/// One row of a migration spreadsheet, after parsing.
///
/// A row that couldn't be understood still becomes a [MigrationRow] — with
/// [error] set — so the preview can show the user exactly which line of
/// their file is wrong instead of failing the whole import with one
/// message.
class MigrationRow {
  final int rowNumber;
  final MigrationKind kind;
  final String rawMember;
  final String? memberUid;
  final int? month;
  final int? year;
  final int day;
  final double? amount;
  final PaymentMethod method;
  final String? reference;
  final String? error;

  /// True when a matching record already exists — re-importing the same
  /// file must not double the ledger.
  final bool duplicate;

  const MigrationRow({
    required this.rowNumber,
    required this.kind,
    required this.rawMember,
    this.memberUid,
    this.month,
    this.year,
    this.day = 1,
    this.amount,
    this.method = PaymentMethod.cash,
    this.reference,
    this.error,
    this.duplicate = false,
  });

  bool get importable => error == null && !duplicate;

  /// Payments are dated to the day; instalments are only ever "this month".
  DateTime get date => DateTime(year!, month!, day);
}

class MigrationPreview {
  final List<MigrationRow> rows;
  const MigrationPreview(this.rows);

  List<MigrationRow> _of(MigrationKind k) => rows.where((r) => r.kind == k && r.importable).toList();

  List<MigrationRow> get contributions => _of(MigrationKind.contribution);
  List<MigrationRow> get payments => _of(MigrationKind.payment);
  List<MigrationRow> get importable => rows.where((r) => r.importable).toList();
  List<MigrationRow> get failed => rows.where((r) => r.error != null).toList();
  List<MigrationRow> get duplicates => rows.where((r) => r.duplicate).toList();

  double get contributionTotal => contributions.fold<double>(0, (t, r) => t + (r.amount ?? 0));
  double get paymentTotal => payments.fold<double>(0, (t, r) => t + (r.amount ?? 0));
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

  /// One layout for both kinds of row. Every row says which it is in column
  /// A, so nothing depends on where it sits in the sheet.
  static const headers = ['ধরন', 'সদস্য', 'মাস', 'বছর', 'দিন', 'পরিমাণ', 'পদ্ধতি', 'রেফারেন্স'];

  static const contributionLabel = 'কিস্তি';
  static const paymentLabel = 'জমা';

  /// A filled-in example rather than an empty grid: the fastest way to
  /// explain a format is to show it, with the group's own member names
  /// already in place and one row of each kind.
  static Uint8List buildTemplate({
    required LandGroup group,
    required List<GroupMember> members,
    required Map<String, String> memberNames,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'হিসাব';
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
        TextCellValue(contributionLabel),
        TextCellValue(memberNames[m.uid] ?? m.uid),
        IntCellValue(now.month),
        IntCellValue(now.year),
        TextCellValue(''),
        DoubleCellValue(m.monthlyAmount == 0 ? 5000 : m.monthlyAmount),
        TextCellValue('নগদ'),
        TextCellValue(''),
      ]);
    }
    if (active.isEmpty) {
      sheet.appendRow([
        TextCellValue(contributionLabel),
        TextCellValue('সদস্যের নাম'),
        IntCellValue(now.month),
        IntCellValue(now.year),
        TextCellValue(''),
        DoubleCellValue(5000),
        TextCellValue('নগদ'),
        TextCellValue(''),
      ]);
    }

    // The outgoing side, shown with a day and a reference so it is obvious
    // those two columns belong to this kind of row.
    sheet.appendRow([
      TextCellValue(paymentLabel),
      TextCellValue(''),
      IntCellValue(now.month),
      IntCellValue(now.year),
      IntCellValue(10),
      DoubleCellValue(group.monthlyTotalToBuilder == 0 ? 15000 : group.monthlyTotalToBuilder),
      TextCellValue('ব্যাংক'),
      TextCellValue('রসিদ নম্বর'),
    ]);

    return Uint8List.fromList(excel.save()!);
  }

  /// Parses and validates without writing anything. The caller shows the
  /// result and asks for confirmation — an import that silently rewrites a
  /// group's money history is not something to trigger from one tap.
  static MigrationPreview parse({
    required Uint8List bytes,
    required List<GroupMember> members,
    required Map<String, String> memberNames,
    required List<Contribution> existingContributions,
    required List<BuilderPayment> existingPayments,
  }) {
    // Read through XlsxReader rather than the excel package: the file being
    // imported was written by some other tool, and that is the whole point
    // of an import — see lib/utils/xlsx_reader.dart for what it survives
    // that the package's reader does not.
    final sheet = XlsxReader.firstSheet(bytes);
    final rows = <MigrationRow>[];

    // Match on the name as typed, case- and space-insensitive, because
    // whoever fills the sheet will not match the app's casing exactly.
    String norm(String v) => v.trim().toLowerCase();
    final byKey = <String, String>{};
    for (final m in members) {
      final name = memberNames[m.uid];
      if (name != null && name.trim().isNotEmpty) byKey[norm(name)] = m.uid;
    }

    // Row 0 is the header; everything after it is data, and the index maps
    // straight onto the spreadsheet's own row numbers for error messages.
    for (var i = 1; i < sheet.rows.length; i++) {
      final cells = sheet.rows[i];
      String cell(int idx) => idx < cells.length ? cells[idx].trim() : '';

      final rawKind = cell(0);
      final rawMember = cell(1);
      final rawAmount = cell(5);
      // A trailing blank row is normal in a spreadsheet, not an error.
      if (rawKind.isEmpty && rawMember.isEmpty && rawAmount.isEmpty) continue;

      final rowNumber = i + 1;
      final kind = _kindFrom(rawKind, hasMember: rawMember.isNotEmpty);

      MigrationRow fail(String message) => MigrationRow(
            rowNumber: rowNumber,
            kind: kind,
            rawMember: rawMember,
            error: message,
          );

      final month = _int(cell(2));
      final year = _int(cell(3));
      final amount = _number(rawAmount);

      if (month == null || month < 1 || month > 12) {
        rows.add(fail('মাস ১-১২ এর মধ্যে দিন'));
        continue;
      }
      if (year == null || year < 2000 || year > 2100) {
        rows.add(fail('বছরটি সঠিক নয়'));
        continue;
      }
      if (amount == null || amount <= 0) {
        rows.add(fail('পরিমাণ সঠিক নয়'));
        continue;
      }

      final method = _methodFrom(cell(6));
      final reference = cell(7).isEmpty ? null : cell(7);

      if (kind == MigrationKind.contribution) {
        final uid = byKey[norm(rawMember)];
        if (uid == null) {
          rows.add(fail(rawMember.isEmpty ? 'সদস্যের নাম লিখুন' : 'এই নামে কোনো সদস্য নেই'));
          continue;
        }
        final duplicate = existingContributions.any((c) =>
            c.memberId == uid &&
            c.month == month &&
            c.year == year &&
            (c.amount - amount).abs() < 0.005 &&
            c.status != ContributionStatus.cancelled);
        rows.add(MigrationRow(
          rowNumber: rowNumber,
          kind: kind,
          rawMember: rawMember,
          memberUid: uid,
          month: month,
          year: year,
          amount: amount,
          method: method,
          reference: reference,
          duplicate: duplicate,
        ));
      } else {
        // Payments are dated to the day. A blank day is not an error — most
        // old ledgers only recorded the month — so it falls back to the 1st.
        final day = _int(cell(4)) ?? 1;
        if (day < 1 || day > 31) {
          rows.add(fail('দিন ১-৩১ এর মধ্যে দিন'));
          continue;
        }
        final duplicate = existingPayments.any((p) =>
            p.date.year == year &&
            p.date.month == month &&
            p.date.day == day &&
            (p.amount - amount).abs() < 0.005);
        rows.add(MigrationRow(
          rowNumber: rowNumber,
          kind: kind,
          rawMember: rawMember,
          month: month,
          year: year,
          day: day,
          amount: amount,
          method: method,
          reference: reference,
          duplicate: duplicate,
        ));
      }
    }

    return MigrationPreview(rows);
  }

  /// Numbers as people actually type them: Bangla digits, thousands
  /// separators, a stray currency symbol, or a spreadsheet's own "50000.0".
  /// A sheet filled in by hand in Bangla should not fail on its own digits.
  static const _bengaliDigits = '০১২৩৪৫৬৭৮৯';

  static String _asciiDigits(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      final char = String.fromCharCode(rune);
      final index = _bengaliDigits.indexOf(char);
      buffer.write(index >= 0 ? '$index' : char);
    }
    return buffer.toString();
  }

  static String _clean(String raw) =>
      _asciiDigits(raw).replaceAll(',', '').replaceAll('৳', '').replaceAll(' ', '').trim();

  static int? _int(String raw) {
    final cleaned = _clean(raw);
    return int.tryParse(cleaned) ?? double.tryParse(cleaned)?.round();
  }

  static double? _number(String raw) => double.tryParse(_clean(raw));

  /// A blank type column is forgiving rather than fatal: a row with a member
  /// named in it can only be an instalment, and one without can only be a
  /// payment out.
  static MigrationKind _kindFrom(String raw, {required bool hasMember}) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return hasMember ? MigrationKind.contribution : MigrationKind.payment;
    const paymentWords = ['জমা', 'বিল্ডার', 'ব্যাংক', 'payment', 'deposit', 'builder', 'bank', 'out'];
    if (paymentWords.any(v.contains)) return MigrationKind.payment;
    return MigrationKind.contribution;
  }

  static PaymentMethod _methodFrom(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('বিকাশ') || v.contains('bkash')) return PaymentMethod.bkash;
    if (v.contains('ব্যাংক') || v.contains('bank')) return PaymentMethod.bank;
    if (v.contains('নগদ') || v.contains('cash')) return PaymentMethod.cash;
    if (v.isEmpty) return PaymentMethod.cash;
    return PaymentMethod.other;
  }

  /// Writes the importable rows: instalments as approved contributions,
  /// outgoing rows into the builder/bank ledger.
  ///
  /// Contributions arrive approved because they are history being recorded,
  /// not claims awaiting review — but everything written here carries
  /// `importedAt`, so the ledger can always distinguish a record someone
  /// entered as it happened from one that arrived in bulk.
  Future<int> import({
    required String groupId,
    required MigrationPreview preview,
    required String importedBy,
  }) async {
    final contributions = preview.contributions;
    final payments = preview.payments;
    if (contributions.isEmpty && payments.isEmpty) return 0;

    final group = _db.collection('groups').doc(groupId);
    final contribCol = group.collection('contributions');
    final paymentCol = group.collection('builderPayments');
    final now = DateTime.now();

    // Firestore caps a batch at 500 writes; a few years of a large group
    // clears that easily.
    const chunkSize = 400;

    for (var start = 0; start < contributions.length; start += chunkSize) {
      final batch = _db.batch();
      for (final r in contributions.skip(start).take(chunkSize)) {
        final ref = contribCol.doc();
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

    for (var start = 0; start < payments.length; start += chunkSize) {
      final batch = _db.batch();
      for (final r in payments.skip(start).take(chunkSize)) {
        final ref = paymentCol.doc();
        batch.set(
          ref,
          BuilderPayment(
            id: ref.id,
            groupId: groupId,
            amount: r.amount!,
            date: r.date,
            referenceNumber: r.reference,
            recordedBy: importedBy,
            recordedAt: now,
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
      details: 'Excel থেকে আমদানি: ${contributions.length} টি কিস্তি, '
          '${payments.length} টি জমার এন্ট্রি',
    );
    return contributions.length + payments.length;
  }
}
