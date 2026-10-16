# ProGuard / R8 rules for SRMOne Mobile
# Keep ONNX Runtime JNI bindings and native libraries
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Keep SQLite3 native libs
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# Keep WorkManager
-keep class androidx.work.** { *; }
