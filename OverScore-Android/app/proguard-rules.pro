# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.scoreframe.model.**$$serializer { *; }
-keepclassmembers class com.scoreframe.model.** {
    *** Companion;
}
-keepclasseswithmembers class com.scoreframe.model.** {
    kotlinx.serialization.KSerializer serializer(...);
}
