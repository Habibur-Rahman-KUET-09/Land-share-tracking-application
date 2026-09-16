import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';

/// Wraps FirebaseAuth for both sign-in methods the FRD requires (phone OTP
/// and email/password), and bootstraps the matching users/{uid} profile
/// document on first sign-in.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? db, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // True while one of the calls below is signing a user in and is about to
  // write their profile itself, with the real name in hand. Firebase's
  // authStateChanges stream can fire — and race AppAuthProvider's own
  // ensureProfile(user) call (no name) — before that write below completes;
  // since ensureProfile() is a no-op once the doc exists, whichever write
  // lands first wins *forever*. AppAuthProvider checks this flag and skips
  // its own call while it's true, so the listener can never win that race
  // with a blank name.
  bool _bootstrapping = false;
  bool get isBootstrapping => _bootstrapping;

  // ---------------------------------------------------------------------
  // Email/password
  // ---------------------------------------------------------------------

  Future<UserCredential> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    _bootstrapping = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await ensureProfile(cred.user!, name: name, email: email);
      return cred;
    } finally {
      _bootstrapping = false;
    }
  }

  Future<UserCredential> signInWithEmail({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // ---------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------

  Future<UserCredential> signInWithGoogle() async {
    _bootstrapping = true;
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw FirebaseAuthException(code: 'sign-in-canceled', message: 'Google sign-in was canceled.');
      }
      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      await ensureProfile(result.user!, name: account.displayName, email: account.email);
      return result;
    } finally {
      _bootstrapping = false;
    }
  }

  // ---------------------------------------------------------------------
  // Phone OTP
  // ---------------------------------------------------------------------

  /// Starts phone verification. [onCodeSent] receives the verificationId to
  /// pass into [confirmPhoneCode]. [onAutoVerified] fires if the platform
  /// auto-retrieves the SMS code (Android) before the user types it.
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(UserCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException error) onFailed,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        final result = await _auth.signInWithCredential(credential);
        onAutoVerified(result);
      },
      verificationFailed: onFailed,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<UserCredential> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
    String? nameIfNewUser,
  }) async {
    _bootstrapping = true;
    try {
      final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
      final result = await _auth.signInWithCredential(credential);
      await ensureProfile(result.user!, name: nameIfNewUser, phone: result.user!.phoneNumber);
      return result;
    } finally {
      _bootstrapping = false;
    }
  }

  // ---------------------------------------------------------------------

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<AppUser?> getProfile(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromMap(uid, snap.data()!);
  }

  Stream<AppUser?> watchProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
          (snap) => snap.exists ? AppUser.fromMap(uid, snap.data()!) : null,
        );
  }

  /// Lets a group's Creator/Admin correct another member's display name
  /// from that group's Members tab (e.g. one stuck with the
  /// "নতুন ব্যবহারকারী" fallback from a bad sign-up) — there's no
  /// self-service profile editor, so this is the only way to fix it.
  ///
  /// [viaGroupId] is written alongside the name purely as the security
  /// rule's proof of authority: it lets the rule verify, from that one
  /// group's own member doc, that the caller really is that group's
  /// Creator/Admin and that [targetUid] really is a member of it — rules
  /// can't search "every group" for that relationship, only check one
  /// it's told about.
  Future<void> updateMemberNameAsManager({
    required String targetUid,
    required String name,
    required String viaGroupId,
  }) async {
    await _db.collection('users').doc(targetUid).update({
      'name': name.trim(),
      'nameLastEditedByGroupId': viaGroupId,
    });
  }

  /// Same as [updateMemberNameAsManager], for the profile's `email` field —
  /// this is just the profile/search field shown on the Members tab and
  /// used by "add member by email"; it does not touch the member's actual
  /// FirebaseAuth sign-in email, so changing it never affects their login.
  Future<void> updateMemberEmailAsManager({
    required String targetUid,
    required String email,
    required String viaGroupId,
  }) async {
    await _db.collection('users').doc(targetUid).update({
      'email': email.trim(),
      'emailLastEditedByGroupId': viaGroupId,
    });
  }

  /// Creates the users/{uid} profile document on first sign-in, for any
  /// auth method. No-op if the profile already exists (idempotent, so it's
  /// safe to call from multiple sign-in paths and a central listener).
  Future<void> ensureProfile(User user, {String? name, String? phone, String? email}) async {
    final ref = _db.collection('users').doc(user.uid);
    final existing = await ref.get();
    if (existing.exists) return;
    final profile = AppUser(
      uid: user.uid,
      name: name?.trim().isNotEmpty == true ? name!.trim() : (user.displayName ?? 'নতুন ব্যবহারকারী'),
      phone: phone ?? user.phoneNumber,
      email: email ?? user.email,
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
    );
    await ref.set(profile.toMap());
  }
}
