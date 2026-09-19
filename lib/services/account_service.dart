import 'package:cloud_functions/cloud_functions.dart';

/// Deleting an account and handing over a group both happen server-side
/// (functions/index.js), because both need writes no client may make: one
/// removes a Firebase Auth user, the other changes two member docs and the
/// group doc as a single unit.
///
/// This class exists to keep `FirebaseFunctionsException` out of the
/// widgets. It turns the function's error codes into either a plain
/// message or, for the one case the user can act on, a typed exception
/// carrying the group names that are in the way.
class AccountService {
  final FirebaseFunctions _functions;

  AccountService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Deletes the signed-in user's account. The caller is signed out
  /// afterwards by [AuthService.signOut] — this does not do it, because a
  /// failed deletion must leave the session exactly as it was.
  Future<void> deleteAccount() async {
    try {
      await _functions.httpsCallable('deleteAccount').call();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        final details = e.details;
        final groups = details is Map && details['groups'] is List
            ? List<String>.from(details['groups'] as List)
            : const <String>[];
        throw CreatorOfLiveGroups(groups);
      }
      throw StateError(e.message ?? 'অ্যাকাউন্ট মুছতে সমস্যা হয়েছে।');
    }
  }

  Future<void> transferCreator({
    required String groupId,
    required String newCreatorUid,
  }) async {
    try {
      await _functions.httpsCallable('transferCreator').call({
        'groupId': groupId,
        'newCreatorUid': newCreatorUid,
      });
    } on FirebaseFunctionsException catch (e) {
      throw StateError(e.message ?? 'দায়িত্ব হস্তান্তর করা যায়নি।');
    }
  }
}

/// The one refusal a user can do something about: they still run groups
/// that other people are in. [groups] are those groups' names, so the app
/// can say which rather than making them guess.
class CreatorOfLiveGroups implements Exception {
  final List<String> groups;
  const CreatorOfLiveGroups(this.groups);

  @override
  String toString() => groups.join(', ');
}
