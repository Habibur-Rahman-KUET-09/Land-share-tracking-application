/// Short Bangla month names for report tables.
///
/// The matrix report used English abbreviations ("Mar-2020") drawn in the
/// Bangla font the PDF ships — and NotoSansBengali carries no Latin
/// letters, so every month came out as boxes with only the year readable.
/// Bangla names avoid the missing-glyph problem outright and suit a report
/// whose every other heading is Bangla.
///
/// Short forms rather than full ones: the matrix has a column per member,
/// so the month column has to stay narrow.
const banglaMonthAbbr = <String>[
  'জানু',
  'ফেব্রু',
  'মার্চ',
  'এপ্রি',
  'মে',
  'জুন',
  'জুলা',
  'আগ',
  'সেপ্ট',
  'অক্টো',
  'নভে',
  'ডিসে',
];
