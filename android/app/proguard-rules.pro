# R8 keep-rules for the release build (isMinifyEnabled = true).
#
# R8 was once enabled here without these rules and the app wouldn't open at
# all on a real Android 10 phone — it had stripped or renamed something
# Firebase reached for by name at runtime. Everything below exists to make
# that impossible again, so nothing here is decoration: removing a rule
# means re-testing a release build on a device.

# ---------------------------------------------------------------------------
# Attributes. R8 drops these unless asked, and anything doing reflection or
# generics inspection breaks silently without them. SourceFile/LineNumberTable
# keep Play Console's crash reports readable instead of a wall of a.b.c().
# ---------------------------------------------------------------------------
-keepattributes Signature,InnerClasses,EnclosingMethod,Exceptions
-keepattributes *Annotation*,AnnotationDefault
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
-keepattributes RuntimeVisibleTypeAnnotations
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---------------------------------------------------------------------------
# Anything explicitly marked as "do not touch" by AndroidX/Firebase.
# ---------------------------------------------------------------------------
-keep class androidx.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <methods>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <fields>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <init>(...);
}

# ---------------------------------------------------------------------------
# Standard Android shapes the platform instantiates by name, not by call.
# ---------------------------------------------------------------------------
-keepclasseswithmembernames class * {
    native <methods>;
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ---------------------------------------------------------------------------
# Flutter. The engine finds the embedding, the plugin registrant and each
# plugin's entry class reflectively from Dart, so none of it can be renamed.
# It is a small amount of Java either way — the bulk of this app is Dart in
# libapp.so, which R8 never sees.
# ---------------------------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# The app's own Java/Kotlin side: MainActivity is named in the manifest, but
# keeping the package whole costs nothing and removes a class of surprise.
-keep class com.veryfew.kistify.** { *; }

# ---------------------------------------------------------------------------
# Flutter's embedding defensively references Google Play Core's
# split-install/deferred-component classes even though this app doesn't use
# deferred components or dynamic feature modules — without the actual
# play-core dependency present, R8 treats those as missing classes and fails
# the build (not just a warning) unless told to ignore them.
# ---------------------------------------------------------------------------
-dontwarn com.google.android.play.core.**

# ---------------------------------------------------------------------------
# Firebase and Google Sign-In. Auth sessions, credentials and Firestore's
# document<->object mapping are all resolved by field/class name at runtime,
# and this is exactly where the earlier crash came from. Keep them whole;
# they are a few hundred KB against an app that is already ~70 MB.
# ---------------------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore serializes/deserializes through these annotations by name.
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName *;
}

# FirebaseMessagingService subclasses are started by the OS from the manifest.
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }

# ---------------------------------------------------------------------------
# Kotlin runtime bits that reflection-based libraries read.
# ---------------------------------------------------------------------------
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# ---------------------------------------------------------------------------
# javax.annotation / error-prone annotations arrive transitively with the
# Firebase SDKs and are compile-time only — absent at runtime by design.
# ---------------------------------------------------------------------------
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**
