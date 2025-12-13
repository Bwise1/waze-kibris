# Flutter and Dart related rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter deferred components - suppress missing Play Core warnings
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Mapbox Maps
-keep class com.mapbox.** { *; }
-dontwarn com.mapbox.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Location services
-keep class com.lyokone.location.** { *; }
-dontwarn com.lyokone.location.**

# TTS (Text-to-Speech)
-keep class com.tundralabs.fluttertts.** { *; }
-dontwarn com.tundralabs.fluttertts.**

# Permission handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# Local notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# Keep AndroidX annotations with explicit constructors for R8
-keep @interface androidx.annotation.Keep { void <init>(); }
-keep @androidx.annotation.Keep class * { void <init>(); }

# Keep Google Play Services annotations with explicit constructors
-keep @interface com.google.android.gms.common.annotation.KeepName { void <init>(); }
-keep,allowshrinking @com.google.android.gms.common.annotation.KeepName class * { void <init>(); }
-keep @interface com.google.android.gms.common.util.DynamiteApi { void <init>(); }

# Keep versioned parcelable with explicit constructors
-keep class * implements androidx.versionedparcelable.VersionedParcelable { void <init>(); }
-keep public class androidx.versionedparcelable.ParcelImpl { void <init>(); }

# Keep startup runtime with explicit constructors
-keep,allowshrinking class * extends androidx.startup.Initializer { void <init>(); }

# Keep OkHttp with explicit constructors
-keep,allowshrinking class okhttp3.internal.publicsuffix.PublicSuffixDatabase { void <init>(); }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelables
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Remove debug logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}