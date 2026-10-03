# Flutter Local Notifications & Gson R8/ProGuard Rules
-keepattributes *Annotation*
-keepattributes Signature
-keepclassmembers class * extends java.lang.Enum {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
