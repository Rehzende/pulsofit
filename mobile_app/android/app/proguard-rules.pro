# Flutter ProGuard Rules
# Needed for Flutter's basic functionality
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Prevent obfuscation of R classes
-keep class **.R$* {
    <fields>;
}

# Standard Android rules
-dontwarn android.arch.**
-dontwarn androidx.**
-dontwarn com.google.android.gms.**

# Fix for missing Play Store Split Install classes
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

