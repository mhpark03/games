# Flutter ProGuard Rules

# Google Play Games Input SDK
-keep class com.google.android.libraries.play.hpe.** { *; }
-keep class com.google.android.libraries.play.games.inputmapping.** { *; }

# Keep Flutter related classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
