// Real values for Android and web, taken from the Firebase console
// (project "landsharetrackingsystem"). iOS hasn't been registered there
// yet, so it still throws until an app is added for that platform and its
// config filled in below (or `flutterfire configure` is run with
// network/login access, see README.md "Firebase setup").
//
// These keys are not secrets: every web/Android client ships them, and
// Firebase identifies rather than authorizes with them. What actually
// guards the data is firestore.rules / storage.rules.
//
// The throw is caught in main() and rendered as a readable message rather
// than a blank screen, so an unconfigured platform says so out loud.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC2CwfOg1aemsHDwQo3ZL_OE7TRq8JJJdE',
    appId: '1:510783432326:web:24a779e3f1273e462e5307',
    messagingSenderId: '510783432326',
    projectId: 'landsharetrackingsystem',
    authDomain: 'landsharetrackingsystem.firebaseapp.com',
    storageBucket: 'landsharetrackingsystem.firebasestorage.app',
    measurementId: 'G-ES1HYVDMXK',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDks9FxaKAinOy-5xFkrQkEixvVw9mPlu4',
    appId: '1:510783432326:android:e758f7582d03eea32e5307',
    messagingSenderId: '510783432326',
    projectId: 'landsharetrackingsystem',
    storageBucket: 'landsharetrackingsystem.firebasestorage.app',
  );
}
