import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/group_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // NFR "অফলাইনেও যেন basic data entry করা যায় (পরে sync)" — Firestore
  // already persists offline by default on Android/iOS; set explicitly so
  // the intent is documented here rather than relying on the SDK default.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  runApp(const LandInstallmentApp());
}

class LandInstallmentApp extends StatelessWidget {
  const LandInstallmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Land Installment Tracker',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.firebaseUser == null) {
      return const LoginScreen();
    }
    // Signed in to Firebase Auth, but the users/{uid} profile couldn't be
    // read/created (most likely firestore.rules hasn't been deployed to the
    // Firebase console yet, so the default rules deny the read) — show this
    // instead of silently landing on a broken/empty group list.
    if (auth.profile == null && auth.authError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                const Text(
                  'প্রোফাইল লোড করা যায়নি। Firestore security rules ডিপ্লয় করা আছে '
                  'কিনা Firebase Console এ চেক করুন (Firestore Database > Rules)।',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  auth.authError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.read<AppAuthProvider>().refreshProfile(),
                  child: const Text('আবার চেষ্টা করুন'),
                ),
                TextButton(
                  onPressed: () => context.read<AppAuthProvider>().signOut(),
                  child: const Text('সাইন আউট'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const GroupListScreen();
  }
}
