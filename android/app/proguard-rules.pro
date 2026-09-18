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
