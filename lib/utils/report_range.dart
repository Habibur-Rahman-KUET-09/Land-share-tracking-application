import '../models/builder_payment.dart';
import '../models/contribution.dart';
import '../models/land_group.dart';

/// The months a report's rows should cover.
///
/// Deliberately not "from when the group was created". A group that brought
/// years of history in from a spreadsheet was created in the app last week,
/// and starting there printed a matrix with a single row while every
/// imported month sat outside the range — the report looked empty for a
/// group whose ledger was full.
///
/// The span is whatever the records actually cover, widened to include the
/// group's own start and the current month, so an active group still shows
/// the months nobody paid in.
List<DateTime> reportMonths({
  required LandGroup group,
  required Iterable<Contribution> contributions,
  required Iterable<BuilderPayment> payments,
}) {
  final now = DateTime.now();
  var first = DateTime(group.createdAt.year, group.createdAt.month);
  var last = DateTime(now.year, now.month);

  void widen(DateTime month) {
    if (month.isBefore(first)) first = month;
    if (month.isAfter(last)) last = month;
  }

  for (final c in contributions) {
    widen(DateTime(c.year, c.month));
  }
  for (final p in payments) {
    widen(DateTime(p.date.year, p.date.month));
  }

  final months = <DateTime>[];
  var cursor = first;
  while (!cursor.isAfter(last)) {
    months.add(cursor);
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return months;
}
