# Firebase Messaging + AppCheck + native SDKs keep-rules.
-keepattributes *Annotation*, InnerClasses
-keepattributes Signature, EnclosingMethod

-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

-keep class com.appsflyer.** { *; }
-dontwarn com.appsflyer.**

-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

-keep class androidx.lifecycle.DefaultLifecycleObserver

# Suppress OkHttp / kotlinx.coroutines warnings that come with the shell.
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn kotlinx.coroutines.**

# ── Microsoft Clarity SDK ────────────────────────────────────────────────
# Clarity uses OkHttp + reflection to serialise sessions; R8 must NOT
# strip or rename its classes or replay uploads fail silently in release.
-keep class com.microsoft.clarity.** { *; }
-keep interface com.microsoft.clarity.** { *; }
-dontwarn com.microsoft.clarity.**

# clarity_flutter plugin channel + Gson models used by Clarity.
-keep class io.dyte.clarity_flutter.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter { *; }
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses

# OkHttp platform detection (Clarity + AppsFlyer both bundle OkHttp).
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
-keep interface okio.** { *; }

# Kotlin metadata (reflection used by Clarity's serializer).
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata { *; }
