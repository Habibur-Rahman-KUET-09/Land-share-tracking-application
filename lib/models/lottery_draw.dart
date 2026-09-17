import 'package:cloud_firestore/cloud_firestore.dart';

/// One month's lottery result in a [GroupType.lottery] group
/// (groups/{groupId}/lotteryDraws/{id}).
///
/// [collectedAmount] is snapshotted at draw time rather than recomputed
/// later: it's what the winner actually received, and it must not shift if
/// a contribution is approved or cancelled after the fact.
class LotteryDraw {
  final String id;
  final String groupId;
  final int month; // 1-12
  final int year;
  final String winnerUid;
  final double collectedAmount;

  /// True when the app picked the winner itself, false when an admin
  /// recorded the result of a draw held in person — worth keeping, since
  /// "who chose this" is exactly what members question later.
  final bool wasRandom;
  final String drawnBy;
  final DateTime drawnAt;
  final String? note;

  const LotteryDraw({
    required this.id,
    required this.groupId,
    required this.month,
    required this.year,
    required this.winnerUid,
    required this.collectedAmount,
    required this.wasRandom,
    required this.drawnBy,
    required this.drawnAt,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'year': year,
      'winnerUid': winnerUid,
      'collectedAmount': collectedAmount,
      'wasRandom': wasRandom,
      'drawnBy': drawnBy,
      'drawnAt': Timestamp.fromDate(drawnAt),
      'note': note,
    };
  }

  factory LotteryDraw.fromMap(String groupId, String id, Map<String, dynamic> map) {
    return LotteryDraw(
      id: id,
      groupId: groupId,
      month: (map['month'] as num?)?.toInt() ?? 1,
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      winnerUid: (map['winnerUid'] as String?) ?? '',
      collectedAmount: (map['collectedAmount'] as num?)?.toDouble() ?? 0,
      wasRandom: (map['wasRandom'] as bool?) ?? false,
      drawnBy: (map['drawnBy'] as String?) ?? '',
      drawnAt: (map['drawnAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }
}
