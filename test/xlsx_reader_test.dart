import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:land_installment_tracker/models/group_member.dart';
import 'package:land_installment_tracker/services/migration_service.dart';
import 'package:land_installment_tracker/utils/xlsx_reader.dart';

/// Builds a .xlsx from raw parts, so a test can reproduce exactly how some
/// other tool lays one out. The shapes below are taken from real files:
/// one written by the `excel` package (our own template), one by openpyxl.
Uint8List xlsx({
  required String workbookRels,
  required String sheetXml,
  String? sharedStrings,
  String sheetPath = 'xl/worksheets/sheet1.xml',
}) {
  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml',
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>');
  add('xl/workbook.xml',
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheets><sheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'name="হিসাব" sheetId="1" r:id="rId1"/></sheets></workbook>');
  add('xl/_rels/workbook.xml.rels', workbookRels);
  add(sheetPath, sheetXml);
  if (sharedStrings != null) add('xl/sharedStrings.xml', sharedStrings);

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String inlineCell(String ref, String text) =>
    '<c r="$ref" t="inlineStr"><is><t>$text</t></is></c>';

String numberCell(String ref, String value) => '<c r="$ref" t="n"><v>$value</v></c>';

void main() {
  group('XlsxReader', () {
    test('reads a sheet whose relationship target is an absolute part name', () {
      // openpyxl writes Target="/xl/worksheets/sheet1.xml". Naively joining
      // that onto "xl/" looks for "xl//xl/worksheets/sheet1.xml", finds
      // nothing, and takes down the whole import — which is exactly what
      // happened to a real file.
      final bytes = xlsx(
        workbookRels:
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            'Target="/xl/worksheets/sheet1.xml" Id="rId1"/></Relationships>',
        sheetXml: '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<sheetData>'
            '<row r="1">${inlineCell('A1', 'ধরন')}${inlineCell('B1', 'সদস্য')}</row>'
            '<row r="2">${inlineCell('A2', 'কিস্তি')}${inlineCell('B2', 'Habibur Rahman')}</row>'
            '</sheetData></worksheet>',
      );

      final sheet = XlsxReader.firstSheet(bytes);
      expect(sheet.name, 'হিসাব');
      expect(sheet.rows[0], ['ধরন', 'সদস্য']);
      expect(sheet.rows[1], ['কিস্তি', 'Habibur Rahman']);
    });

    test('tolerates an inline-string cell with no text in it', () {
      // <c t="inlineStr"/> — a cleared cell that kept its type. Reading it
      // as "the first <t> element" throws on an empty iterable.
      final bytes = xlsx(
        workbookRels:
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            'Target="worksheets/sheet1.xml"/></Relationships>',
        sheetXml: '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<sheetData>'
            '<row r="1">${inlineCell('A1', 'ধরন')}${inlineCell('B1', 'সদস্য')}${inlineCell('C1', 'মাস')}</row>'
            '<row r="2">${inlineCell('A2', 'জমা')}<c r="B2" t="inlineStr"></c>${numberCell('C2', '3')}</row>'
            '</sheetData></worksheet>',
      );

      final sheet = XlsxReader.firstSheet(bytes);
      expect(sheet.rows[1], ['জমা', '', '3']);
    });

    test('resolves shared strings and keeps row numbers of skipped rows', () {
      final bytes = xlsx(
        workbookRels:
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            'Target="worksheets/sheet1.xml"/></Relationships>',
        sharedStrings: '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="2" uniqueCount="2">'
            '<si><t>ধরন</t></si><si><r><t>কি</t></r><r><t>স্তি</t></r></si></sst>',
        sheetXml: '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<sheetData>'
            '<row r="1"><c r="A1" t="s"><v>0</v></c></row>'
            '<row r="4"><c r="A4" t="s"><v>1</v></c></row>'
            '</sheetData></worksheet>',
      );

      final sheet = XlsxReader.firstSheet(bytes);
      expect(sheet.rows.length, 4);
      expect(sheet.rows[0], ['ধরন']);
      expect(sheet.rows[1], isEmpty);
      // Rich text split across runs is one string in the cell.
      expect(sheet.rows[3], ['কিস্তি']);
    });

    test('refuses something that is not a spreadsheet, in words', () {
      expect(
        () => XlsxReader.firstSheet(Uint8List.fromList(utf8.encode('not a zip'))),
        throwsA(isA<XlsxFormatException>()),
      );
    });
  });

  group('MigrationService.parse', () {
    final members = [
      GroupMember(
        uid: 'uid-habib',
        groupId: 'g1',
        role: GroupRole.creator,
        monthlyAmount: 5000,
        status: MemberStatus.active,
        joinedAt: DateTime(2024, 1, 1),
      ),
    ];
    const names = {'uid-habib': 'Habibur Rahman'};

    String header() =>
        '<row r="1">${inlineCell('A1', 'ধরন')}${inlineCell('B1', 'সদস্য')}${inlineCell('C1', 'মাস')}'
        '${inlineCell('D1', 'বছর')}${inlineCell('E1', 'দিন')}${inlineCell('F1', 'পরিমাণ')}'
        '${inlineCell('G1', 'পদ্ধতি')}${inlineCell('H1', 'রেফারেন্স')}</row>';

    Uint8List sheetOf(String rows) => xlsx(
          workbookRels:
              '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
              '<Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
              'Target="/xl/worksheets/sheet1.xml" Id="rId1"/></Relationships>',
          sheetXml: '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
              '<sheetData>${header()}$rows</sheetData></worksheet>',
        );

    test('reads both kinds of row out of an openpyxl-shaped file', () {
      final bytes = sheetOf(
        '<row r="2">${inlineCell('A2', 'কিস্তি')}${inlineCell('B2', 'Habibur Rahman')}'
        '${numberCell('C2', '3')}${numberCell('D2', '2020')}<c r="E2" t="n"></c>'
        '${numberCell('F2', '50000')}${inlineCell('G2', 'নগদ')}${inlineCell('H2', 'Downpayment')}</row>'
        '<row r="3">${inlineCell('A3', 'জমা')}<c r="B3" t="inlineStr"></c>'
        '${numberCell('C3', '3')}${numberCell('D3', '2020')}${numberCell('E3', '25')}'
        '${numberCell('F3', '50000')}${inlineCell('G3', 'নগদ')}${inlineCell('H3', 'MR#251')}</row>',
      );

      final preview = MigrationService.parse(
        bytes: bytes,
        members: members,
        memberNames: names,
        existingContributions: const [],
        existingPayments: const [],
      );

      expect(preview.failed, isEmpty);
      expect(preview.contributions.single.memberUid, 'uid-habib');
      expect(preview.contributions.single.amount, 50000);
      expect(preview.payments.single.date, DateTime(2020, 3, 25));
      expect(preview.paymentTotal, 50000);
    });

    test('accepts Bangla digits and thousands separators', () {
      final bytes = sheetOf(
        '<row r="2">${inlineCell('A2', 'কিস্তি')}${inlineCell('B2', 'Habibur Rahman')}'
        '${inlineCell('C2', '৩')}${inlineCell('D2', '২০২০')}<c r="E2" t="n"></c>'
        '${inlineCell('F2', '৫০,০০০')}${inlineCell('G2', 'নগদ')}${inlineCell('H2', '')}</row>',
      );

      final preview = MigrationService.parse(
        bytes: bytes,
        members: members,
        memberNames: names,
        existingContributions: const [],
        existingPayments: const [],
      );

      final row = preview.contributions.single;
      expect(row.month, 3);
      expect(row.year, 2020);
      expect(row.amount, 50000);
    });

    test('names the spreadsheet row a bad line is on', () {
      final bytes = sheetOf(
        '<row r="7">${inlineCell('A7', 'কিস্তি')}${inlineCell('B7', 'Nobody')}'
        '${numberCell('C7', '3')}${numberCell('D7', '2020')}<c r="E7" t="n"></c>'
        '${numberCell('F7', '50000')}${inlineCell('G7', 'নগদ')}${inlineCell('H7', '')}</row>',
      );

      final preview = MigrationService.parse(
        bytes: bytes,
        members: members,
        memberNames: names,
        existingContributions: const [],
        existingPayments: const [],
      );

      expect(preview.failed.single.rowNumber, 7);
    });
  });
}
