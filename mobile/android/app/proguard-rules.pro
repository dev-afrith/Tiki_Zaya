# Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Agora RTC SDK rules
-keep class io.agora.** { *; }
-keep class io.agora.rtc.** { *; }
-keep class io.agora.rtc2.** { *; }
-dontwarn io.agora.**

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Networking (Dio, OkHttp, Retrofit)
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class retrofit2.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**

# Google Fonts
-keep class com.google.fonts.** { *; }

# Shared Preferences / Services
-keep class com.afrith.tikizaya.services.** { *; }

# Handle Kotlin Reflection
-keep class kotlin.reflect.jvm.internal.** { *; }
-dontwarn kotlin.reflect.jvm.internal.**

# Gson/Jackson if used
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Google Play Core / Tasks (Fixes R8 "Missing class" errors)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.tasks.**

# Ignore non-fatal warnings
-ignorewarnings
