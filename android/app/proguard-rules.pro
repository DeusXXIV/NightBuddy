# Keep Flutter JNI bindings and entrypoints
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**    { *; }
-keep class io.flutter.view.**    { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Kotlin/Coroutine metadata
-keepclassmembers class kotlin.Metadata { *; }

# Keep MethodChannel entrypoints (by name) to avoid stripping
-keepclassmembers class com.example.nightbuddy.MainActivity {
    <methods>;
}

# Remove Log calls in release
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}
