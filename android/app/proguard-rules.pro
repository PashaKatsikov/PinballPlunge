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
