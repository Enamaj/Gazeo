# ProGuard / R8 rules for GAZEO Mobile release build
# Ensures Flutter runtime, native methods, and model serializations are safely retained.

# Flutter Wrapper & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve annotated members
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

-dontwarn io.flutter.**
-dontwarn androidx.**

