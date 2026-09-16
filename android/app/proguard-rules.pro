# Flutter's embedding defensively references Google Play Core's
# split-install/deferred-component classes even though this app doesn't use
# deferred components or dynamic feature modules — without the actual
# play-core dependency present, R8 treats those as missing classes and fails
# the build (not just a warning) unless told to ignore them.
-dontwarn com.google.android.play.core.**

# firebase_auth / google_sign_in credential/session classes are parsed via
# reflection in a few spots; keep them intact rather than risk R8 renaming
# or stripping fields that are only ever accessed by name at runtime.
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.auth.** { *; }
