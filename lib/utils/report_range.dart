import '../models/builder_payment.dart';
import '../models/contribution.dart';

/// The months a report's rows should cover: the ones that actually hold a
/// record, oldest first.
///
/// Two things this deliberately does not do.
///
/// It does not start from the group's creation date. A group that brought
/// years of history in from a spreadsheet was created in the app last
/// week, and starting there printed a matrix with a single row while every
/// imported month sat outside the range.
///
/// It does not fill the gaps. A group that paid nothing for five months
/// used to get five empty rows, on the argument that a gap is part of the
/// accounting — but in a ledger spanning years those rows are most of the
/// page, and the months that matter are the ones with money in them.
List<DateTime> reportMonths({
  required Iterable<Contribution> contributions,
  required Iterable<BuilderPayment> payments,
}) {
  final months = <DateTime>{};
  for (final c in contributions) {
    months.add(DateTime(c.year, c.month));
  }
  for (final p in payments) {
    months.add(DateTime(p.date.year, p.date.month));
  }

  // A group with nothing recorded yet still gets a row, so its report is
  // an empty table rather than a headless one.
  if (months.isEmpty) {
    final now = DateTime.now();
    return [DateTime(now.year, now.month)];
  }

  return months.toList()..sort();
}
