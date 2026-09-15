import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

/// App-wide auth/session state — who's signed in and their profile.
class AppAuthProvider extends ChangeNotifier {
  final AuthService authService;
  final NotificationService notificationService;

  AppAuthProvider({AuthService? authService, NotificationService? notificationService})
      : authService = authService ?? AuthService(),
        notificationService = notificationService ?? NotificationService() {
    this.authService.authStateChanges.listen(_onAuthChanged);
  }

  User? firebaseUser;
  AppUser? profile;
  bool isLoading = true;
  // Set when the profile couldn't be loaded/created after a successful sign-in
  // (most likely Firestore security rules aren't deployed yet) — surfaced so
  // the UI doesn't just spin forever with no explanation.
  String? authError;

  Future<void> _onAuthChanged(User? user) async {
    firebaseUser = user;
    if (user == null) {
      profile = null;
      authError = null;
      isLoading = false;
      notifyListeners();
      return;
    }
    // ensureProfile/getProfile talk to Firestore, which can throw (e.g. rules
    // not deployed yet) — this must never leave isLoading stuck at true, or
    // the app hangs on the loading spinner after a real, successful sign-in.
    try {
      authError = null;
      await authService.ensureProfile(user);
      profile = await authService.getProfile(user.uid);
    } catch (e) {
      profile = null;
      authError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
    // Fire-and-forget: FCM token registration shouldn't block sign-in.
    notificationService.initForUser(user.uid);
  }

  Future<void> signOut() async {
    await authService.signOut();
  }

  Future<void> refreshProfile() async {
    if (firebaseUser == null) return;
    try {
      authError = null;
      profile = await authService.getProfile(firebaseUser!.uid);
    } catch (e) {
      authError = e.toString();
    }
    notifyListeners();
  }
}
