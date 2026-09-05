# ---------------------------------------------------------
# SKILL//ISSUE R8 / ProGuard rules
# ---------------------------------------------------------

# Godot Android/JNI bridge.
-keep class org.godotengine.godot.** { *; }
-dontwarn org.godotengine.godot.**

# SKILL//ISSUE accesses Play Games through Godot's
# JavaClassWrapper, so preserve the public classes that are
# resolved dynamically by name.
-keep class com.google.android.gms.games.PlayGames { *; }
-keep class com.google.android.gms.games.PlayGamesSdk { *; }
-keep class com.google.android.gms.games.leaderboard.** { *; }