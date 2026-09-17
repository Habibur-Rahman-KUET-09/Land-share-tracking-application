import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contribution.dart';
import '../models/group_member.dart';
import '../models/lottery_draw.dart';
import 'audit_service.dart';

/// The lottery (সমিতি/ROSCA) side of a [GroupType.lottery] group: every
/// month the pooled contributions go to one member drawn by lot, as an
/// interest-free loan they repay by carrying on with their monthly share
/// for the rest of the cycle.
class LotteryService {
  final FirebaseFirestore _db;
  final AuditService _audit;

  LotteryService({FirebaseFirestore? db, AuditService? audit})
      : _db = db ?? FirebaseFirestore.instance,
        _audit = audit ?? AuditService();

  CollectionReference<Map<String, dynamic>> _col(String groupId) =>
      _db.collection('groups').doc(groupId).collection('lotteryDraws');

  Stream<List<LotteryDraw>> watch(String groupId) {
    return _col(groupId).orderBy('drawnAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => LotteryDraw.fromMap(groupId, d.id, d.data())).toList(),
        );
  }

  /// Active members who haven't won yet. Winning is once per member per
  /// cycle, so the pool shrinks by one each month until it's empty — at
  /// which point the cycle is complete (see [isCycleComplete]).
  static List<GroupMember> eligibleMembers(List<GroupMember> members, List<LotteryDraw> draws) {
    final winners = draws.map((d) => d.winnerUid).toSet();
    return members.where((m) => m.isActive && !winners.contains(m.uid)).toList();
  }

  /// True once every active member has had their turn.
  static bool isCycleComplete(List<GroupMember> members, List<LotteryDraw> draws) {
    final active = members.where((m) => m.isActive).toList();
    return active.isNotEmpty && eligibleMembers(members, draws).isEmpty;
  }

  /// What the winner of [month]/[year] takes home: every approved
  /// contribution booked against that month.
  static double potFor(List<Contribution> approvedContributions, int month, int year) {
    return approvedContributions
        .where((c) => c.month == month && c.year == year)
        .fold<double>(0, (total, c) => total + c.amount);
  }

  static LotteryDraw? drawFor(List<LotteryDraw> draws, int month, int year) {
    for (final d in draws) {
      if (d.month == month && d.year == year) return d;
    }
    return null;
  }

  /// Records a draw. Pass [winnerUid] to log a draw held in person, or
  /// leave it null to let the app pick from [eligible] at random.
  ///
  /// Throws if this month already has a result or there's no one left to
  /// win — both would quietly corrupt the cycle otherwise (two winners in
  /// a month, or someone taking a second turn).
  Future<LotteryDraw> recordDraw({
    required String groupId,
    required int month,
    required int year,
    required List<GroupMember> eligible,
    required double collectedAmount,
    required String drawnBy,
    String? winnerUid,
    String? note,
  }) async {
    final existing = await _col(groupId).where('month', isEqualTo: month).where('year', isEqualTo: year).limit(1).get();
    if (existing.docs.isNotEmpty) {
      throw StateError('এই মাসের লটারি ইতিমধ্যে হয়ে গেছে');
    }
    if (eligible.isEmpty) {
      throw StateError('লটারিতে অংশ নেওয়ার মতো কোনো সদস্য বাকি নেই — চক্র শেষ');
    }
    if (winnerUid != null && !eligible.any((m) => m.uid == winnerUid)) {
      throw StateError('এই সদস্য ইতিমধ্যে একবার জিতেছেন, আবার জিততে পারবেন না');
    }

    final wasRandom = winnerUid == null;
    final winner = winnerUid ?? eligible[Random.secure().nextInt(eligible.length)].uid;

    final ref = _col(groupId).doc();
    final draw = LotteryDraw(
      id: ref.id,
      groupId: groupId,
      month: month,
      year: year,
      winnerUid: winner,
      collectedAmount: collectedAmount,
      wasRandom: wasRandom,
      drawnBy: drawnBy,
      drawnAt: DateTime.now(),
      note: note,
    );
    await ref.set(draw.toMap());
    await _audit.log(
      groupId: groupId,
      actorId: drawnBy,
      action: 'lottery_draw',
      targetType: 'lotteryDraw',
      targetId: ref.id,
      details: '$month/$year মাসের লটারি সম্পন্ন (${wasRandom ? 'অ্যাপ ড্র' : 'ম্যানুয়াল'})',
    );
    return draw;
  }
}
