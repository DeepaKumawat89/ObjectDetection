# TensorFlow Lite Proguard / R8 Keep Rules
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

-keep class com.google.android.gms.tflite.** { *; }
-dontwarn com.google.android.gms.tflite.**
