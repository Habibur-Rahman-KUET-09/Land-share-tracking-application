import 'package:flutter/material.dart';

/// Whether [date] falls within [range], inclusive of both end days —
/// [DateTimeRange.end] from [showDateRangePicker] is midnight of that day,
/// so a plain `isBefore`/`isAfter` check would wrongly exclude entries from
/// the end day itself.
bool isInDateRange(DateTime date, DateTimeRange? range) {
  if (range == null) return true;
  final day = DateTime(date.year, date.month, date.day);
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day);
  return !day.isBefore(start) && !day.isAfter(end);
}

/// A "search by date" bar shared by Activity Log, Builder Payments, and
/// Contributions — a button opening a date-range picker, plus a chip
/// showing the active range with a clear (×) action.
class DateRangeFilterBar extends StatelessWidget {
  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onChanged;
  const DateRangeFilterBar({super.key, required this.range, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: range,
    );
    if (picked != null) onChanged(picked);
  }

  String _fmt(DateTime d) => '${d.day}-${d.month}-${d.year}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context),
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(
                range == null ? 'তারিখ দিয়ে খুঁজুন' : '${_fmt(range!.start)} — ${_fmt(range!.end)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (range != null)
            IconButton(
              tooltip: 'ফিল্টার মুছুন',
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => onChanged(null),
            ),
        ],
      ),
    );
  }
}
