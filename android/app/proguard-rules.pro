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
