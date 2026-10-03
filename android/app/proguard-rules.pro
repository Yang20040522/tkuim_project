# These classes are referenced only by optional Firebase Messaging or build-time
# annotation-processing paths. R8 reports them as missing when producing the
# release APK, but they are not required by the app's runtime code paths.
-dontwarn com.google.firebase.messaging.TopicOperation$TopicOperations
-dontwarn javax.lang.model.SourceVersion
-dontwarn javax.lang.model.element.Element
-dontwarn javax.lang.model.element.ElementKind
-dontwarn javax.lang.model.type.TypeMirror
-dontwarn javax.lang.model.type.TypeVisitor
-dontwarn javax.lang.model.util.SimpleTypeVisitor8

# ONNX Runtime resolves parts of its Android API dynamically. R8 must retain
# these classes in release builds so native inference can initialize correctly.
-keep class ai.onnxruntime.** { *; }

# MediaPipe Tasks uses protobuf-lite message metadata to resolve generated
# fields by their original names at runtime. R8 otherwise renames/removes those
# fields and HandLandmarker initialization fails (for example `platform_`).
-keepclassmembers class com.google.mediapipe.** extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}

# MediaPipe Graph initializes a Flogger logger via stack inspection. Inlining
# this factory into Graph removes the logger frame. The caller finder also
# needs its own frame because it skips one stack entry before finding the logger.
# Preserve these two boundaries, not all of MediaPipe/Flogger. Class obfuscation
# and optimization of other methods remain allowed.
-keepclassmembers,allowobfuscation class com.google.common.flogger.FluentLogger {
    public static com.google.common.flogger.FluentLogger forEnclosingClass();
}
-keepclassmembers,allowobfuscation class com.google.common.flogger.backend.system.StackBasedCallerFinder {
    public java.lang.String findLoggingClass(java.lang.Class);
}

# CalculatorGraphConfig contains protobuf Any messages resolved through lite
# schema metadata rather than direct Java construction. R8 otherwise reduces
# Any to an abstract class token and its default-instance lookup fails at runtime.
# Preserve this specific message (including metadata field names), not protobuf.**.
-keep class com.google.protobuf.Any { *; }
