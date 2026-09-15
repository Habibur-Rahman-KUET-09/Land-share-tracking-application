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

  // ---------------------------------------------------------------------
  // Email/password
  // ---------------------------------------------------------------------

  Future<UserCredential> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await ensureProfile(cred.user!, name: name, email: email);
    return cred;
  }

  Future<UserCredential> signInWithEmail({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // ---------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------

  Future<UserCredential> signInWithGoogle() async {
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
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    final result = await _auth.signInWithCredential(credential);
    await ensureProfile(result.user!, name: nameIfNewUser, phone: result.user!.phoneNumber);
    return result;
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

  Future<void> updateProfile({required String uid, String? name, String? photoUrl}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (updates.isEmpty) return;
    await _db.collection('users').doc(uid).update(updates);
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
