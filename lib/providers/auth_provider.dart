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

  Future<void> _onAuthChanged(User? user) async {
    firebaseUser = user;
    if (user == null) {
      profile = null;
      isLoading = false;
      notifyListeners();
      return;
    }
    profile = await authService.getProfile(user.uid);
    isLoading = false;
    notifyListeners();
    // Fire-and-forget: FCM token registration shouldn't block sign-in.
    notificationService.initForUser(user.uid);
  }

  Future<void> signOut() async {
    await authService.signOut();
  }

  Future<void> refreshProfile() async {
    if (firebaseUser == null) return;
    profile = await authService.getProfile(firebaseUser!.uid);
    notifyListeners();
  }
}
