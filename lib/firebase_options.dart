// Real values for Android, extracted from android/app/google-services.json
// (project "landsharetrackingsystem"). iOS/web haven't been registered in
// the Firebase project yet — those two still throw until an app is added
// for that platform in the Firebase console and this file is updated with
// its config (or `flutterfire configure` is run with network/login access,
// see README.md "Firebase setup").
//
// The throw is caught in main() and rendered as a readable message rather
// than a blank screen, so an unconfigured platform says so out loud.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase Console → Project settings → Your apps → Web এ একটি web app '
        'যোগ করে তার config এখানে (DefaultFirebaseOptions.web) বসাতে হবে।',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'No Firebase iOS app has been registered yet in the '
          'landsharetrackingsystem project — add one in the Firebase console '
          '(Project settings > Your apps > iOS) and fill in DefaultFirebaseOptions.ios.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDks9FxaKAinOy-5xFkrQkEixvVw9mPlu4',
    appId: '1:510783432326:android:e758f7582d03eea32e5307',
    messagingSenderId: '510783432326',
    projectId: 'landsharetrackingsystem',
    storageBucket: 'landsharetrackingsystem.firebasestorage.app',
  );
}
