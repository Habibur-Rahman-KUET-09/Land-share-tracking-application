import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// A sheet, reduced to what an importer actually needs: text in a grid.
///
/// [rows] is indexed from zero, but positionally faithful to the file —
/// `rows[4]` is spreadsheet row 5 even if rows 2-4 were blank — because
/// every error this feeds into is reported to a person looking at that
/// spreadsheet, and an off-by-one in "row 37 is wrong" is worse than no
/// message at all.
class XlsxSheet {
  final String name;
  final List<List<String>> rows;
  const XlsxSheet({required this.name, required this.rows});
}

class XlsxFormatException implements Exception {
  final String message;
  const XlsxFormatException(this.message);
  @override
  String toString() => message;
}

/// Reads .xlsx files the way an import feature has to: permissively.
///
/// The `excel` package writes our template well, but its reader assumes
/// the file came from itself. Two things a real-world sheet does that it
/// cannot survive, both found in a file openpyxl produced:
///
///  * a worksheet relationship whose Target is an absolute part name
///    (`/xl/worksheets/sheet1.xml`, not `worksheets/sheet1.xml`) — it
///    concatenates that onto "xl/", looks for `xl//xl/worksheets/sheet1.xml`,
///    finds nothing and dereferences null;
///  * an empty inline-string cell (`<c t="inlineStr"/>`), where it takes
///    `.first` of an empty iterable.
///
/// Neither is a malformed file; both are ordinary output from a tool that
/// is not this one. Since accepting other tools' files is the entire point
/// of an importer, reading the parts ourselves is less fragile than hoping
/// the next writer matches the reader's assumptions.
class XlsxReader {
  const XlsxReader._();

  /// The first sheet in workbook order, which is the only one the
  /// migration format uses.
  static XlsxSheet firstSheet(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const XlsxFormatException(
        'ফাইলটি খোলা গেল না — এটি .xlsx ফাইল কি না দেখে নিন (.xls বা .csv হলে Excel-এ খুলে .xlsx হিসেবে সেভ করুন)।',
      );
    }

    final workbookXml = _xml(archive, 'xl/workbook.xml') ??
        (throw const XlsxFormatException('ফাইলটিতে কোনো ওয়ার্কশিট পাওয়া যায়নি।'));

    final sheetNode = _first(workbookXml.findAllElements('sheet')) ??
        (throw const XlsxFormatException('ফাইলটিতে কোনো ওয়ার্কশিট পাওয়া যায়নি।'));
    final sheetName = sheetNode.getAttribute('name') ?? 'Sheet1';
    final relId = sheetNode.getAttribute('r:id') ?? sheetNode.getAttribute('id');

    final targets = _relationships(archive);
    // Falling back to the conventional path keeps files readable even when
    // the relationship is missing or points somewhere we can't resolve.
    final sheetPath = (relId != null ? targets[relId] : null) ?? 'worksheets/sheet1.xml';
    final sheetXml = _xml(archive, _resolve(sheetPath)) ??
        _xml(archive, 'xl/worksheets/sheet1.xml') ??
        (throw const XlsxFormatException('ওয়ার্কশিটটি পড়া গেল না।'));

    final shared = _sharedStrings(archive, targets);
    return XlsxSheet(name: sheetName, rows: _grid(sheetXml, shared));
  }

  // -------------------------------------------------------------------

  /// `firstOrNull` lives in package:collection; one helper is cheaper than
  /// a dependency for it.
  static XmlElement? _first(Iterable<XmlElement> nodes) =>
      nodes.isEmpty ? null : nodes.first;

  /// Part lookup that tolerates the two spellings of a path seen in the
  /// wild: a leading slash, and a difference in case.
  static ArchiveFile? _file(Archive archive, String path) {
    final want = path.startsWith('/') ? path.substring(1) : path;
    for (final f in archive.files) {
      if (f.name == want) return f;
    }
    final lower = want.toLowerCase();
    for (final f in archive.files) {
      if (f.name.toLowerCase() == lower) return f;
    }
    return null;
  }

  static XmlDocument? _xml(Archive archive, String path) {
    final file = _file(archive, path);
    if (file == null) return null;
    try {
      return XmlDocument.parse(utf8.decode(file.content as List<int>, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }

  /// A relationship Target is relative to the part that declares it —
  /// `xl/` here — unless it is absolute, in which case it is already the
  /// full path and must not be prefixed. Getting this wrong is exactly
  /// the crash this class exists to avoid.
  static String _resolve(String target) {
    if (target.startsWith('/')) return target.substring(1);
    if (target.startsWith('xl/')) return target;
    return 'xl/$target';
  }

  static Map<String, String> _relationships(Archive archive) {
    final doc = _xml(archive, 'xl/_rels/workbook.xml.rels');
    if (doc == null) return const {};
    final map = <String, String>{};
    for (final node in doc.findAllElements('Relationship')) {
      final id = node.getAttribute('Id');
      final target = node.getAttribute('Target');
      if (id != null && target != null) map[id] = target;
    }
    return map;
  }

  static List<String> _sharedStrings(Archive archive, Map<String, String> targets) {
    final explicit = targets.values.firstWhere(
      (t) => t.toLowerCase().endsWith('sharedstrings.xml'),
      orElse: () => 'sharedStrings.xml',
    );
    final doc = _xml(archive, _resolve(explicit)) ?? _xml(archive, 'xl/sharedStrings.xml');
    if (doc == null) return const [];
    // Rich text splits one string across several <t> runs; joining them is
    // what the user sees in the cell.
    return doc
        .findAllElements('si')
        .map((si) => si.findAllElements('t').map((t) => t.innerText).join())
        .toList();
  }

  static List<List<String>> _grid(XmlDocument sheet, List<String> shared) {
    final byRow = <int, List<String>>{};
    var maxRow = 0;

    var fallbackRow = 0;
    for (final row in sheet.findAllElements('row')) {
      fallbackRow++;
      final rowNumber = int.tryParse(row.getAttribute('r') ?? '') ?? fallbackRow;
      fallbackRow = rowNumber;
      if (rowNumber > maxRow) maxRow = rowNumber;

      final cells = <int, String>{};
      var fallbackCol = -1;
      for (final c in row.findElements('c')) {
        fallbackCol++;
        final column = _columnOf(c.getAttribute('r')) ?? fallbackCol;
        fallbackCol = column;
        final value = _value(c, shared);
        if (value.isNotEmpty) cells[column] = value;
      }
      if (cells.isEmpty) {
        byRow[rowNumber] = const [];
        continue;
      }
      final width = cells.keys.reduce((a, b) => a > b ? a : b) + 1;
      byRow[rowNumber] = List<String>.generate(width, (i) => cells[i] ?? '');
    }

    return List<List<String>>.generate(maxRow, (i) => byRow[i + 1] ?? const []);
  }

  /// "B7" -> 1. Returns null when there is no reference to read, letting
  /// the caller fall back to cell order.
  static int? _columnOf(String? reference) {
    if (reference == null || reference.isEmpty) return null;
    var column = 0;
    var seen = false;
    for (final code in reference.toUpperCase().codeUnits) {
      if (code < 65 || code > 90) break;
      column = column * 26 + (code - 64);
      seen = true;
    }
    return seen ? column - 1 : null;
  }

  static String _value(XmlElement cell, List<String> shared) {
    switch (cell.getAttribute('t')) {
      case 's':
        final index = int.tryParse(_first(cell.findElements('v'))?.innerText ?? '');
        if (index == null || index < 0 || index >= shared.length) return '';
        return shared[index];
      case 'inlineStr':
        // May legitimately be empty — an untouched cell that still carries
        // the type from whatever wrote the file.
        return cell.findAllElements('t').map((t) => t.innerText).join();
      case 'b':
        return _first(cell.findElements('v'))?.innerText == '1' ? 'TRUE' : 'FALSE';
      default:
        final v = _first(cell.findElements('v'))?.innerText;
        if (v != null && v.isNotEmpty) return v;
        // Formula results are in <v>; a file saved without cached results
        // has only the formula, which is not a value we can import.
        return cell.findAllElements('t').map((t) => t.innerText).join();
    }
  }
}
