import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// One place that turns a uid into a display name, and remembers the answer.
///
/// Every screen that lists anything shows names — members, contributions,
/// approvals, audit entries, lottery winners. Resolving each one with its
/// own `users/{uid}` get() inside a build method meant a billed Firestore
/// read per widget, repeated on every rebuild and every scroll, for names
/// that change maybe once a year. Caching the *future* (not just the value)
/// also collapses the burst of identical lookups a single list triggers
/// into one request.
///
/// Names are only invalidated deliberately — see [forget], called when an
/// admin renames someone — so a stale name can never outlive the edit that
/// caused it.
class UserDirectory {
  UserDirectory._();
  static final instance = UserDirectory._();

  final Map<String, Future<AppUser?>> _cache = {};

  Future<AppUser?> user(String uid, {FirebaseFirestore? db}) {
    return _cache.putIfAbsent(uid, () async {
      final snap = await (db ?? FirebaseFirestore.instance).collection('users').doc(uid).get();
      if (!snap.exists) return null;
      return AppUser.fromMap(uid, snap.data()!);
    });
  }

  /// A name for a profile that is no longer there.
  ///
  /// This is what every ledger row, approval and audit entry shows once
  /// someone deletes their account: the records stay (they are the whole
  /// group's, not just theirs), but the person behind them is gone. The
  /// last six characters of the uid come along because two people can
  /// leave the same group, and "মুছে ফেলা অ্যাকাউন্ট" twice in one table
  /// tells nobody which row was whose.
  static String deletedLabel(String uid) =>
      'মুছে ফেলা অ্যাকাউন্ট (${uid.length <= 6 ? uid : uid.substring(uid.length - 6)})';

  Future<String> name(String uid, {FirebaseFirestore? db}) async {
    final u = await user(uid, db: db);
    final name = u?.name;
    if (name != null && name.isNotEmpty) return name;
    return deletedLabel(uid);
  }

  /// Drops a cached entry after its profile changed, so the next read is
  /// fresh. Call this from anything that writes users/{uid}.
  void forget(String uid) => _cache.remove(uid);

  /// Used when signing out — the next user must not inherit this one's view.
  void clear() => _cache.clear();

  /// Resolves many uids at once, reusing anything already cached.
  Future<Map<String, String>> names(Iterable<String> uids, {FirebaseFirestore? db}) async {
    final unique = uids.toSet();
    final resolved = await Future.wait(unique.map((uid) => name(uid, db: db)));
    return Map.fromIterables(unique, resolved);
  }
}
