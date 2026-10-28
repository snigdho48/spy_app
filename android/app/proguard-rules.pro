# Flutter / Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Google Play / Firebase / Google Sign-In
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Parcelables / enums used by plugins
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Gson / reflective JSON (plugins)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# permission_handler / geolocator / call_log / etc. — keep native bridges
-keep class com.baseflow.** { *; }
-keep class com.llfbandit.** { *; }

# Don't strip Flutter JNI
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$Registrar { *; }

# Play Core split/deferred APIs are referenced by Flutter's embedding
# (FlutterPlayStoreSplitApplication / PlayStoreDeferredComponentManager) but
# are not on the classpath unless deferred components are used. R8 fails the
# release minify without these dontwarn rules.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
