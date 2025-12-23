# Keep Flutter, Kotlin metadata
-keep class io.flutter.** { *; }
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }

# OkHttp / WebSocket (Supabase realtime)
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-dontwarn okio.**
-keep class okio.** { *; }

# Gson / Moshi (if present)
-dontwarn com.google.gson.**
-keep class com.google.gson.** { *; }
-dontwarn com.squareup.moshi.**
-keep class com.squareup.moshi.** { *; }

# Prevent model reflection stripping (defensive)
-keep class **.model.** { *; }
-keep class **.models.** { *; }

# Google Play Core (deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

