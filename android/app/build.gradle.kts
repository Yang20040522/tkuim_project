plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_body"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.example.flutter_body"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )

    implementation("androidx.camera:camera-core:1.3.1")
    implementation("androidx.camera:camera-camera2:1.3.1")
    implementation("androidx.camera:camera-lifecycle:1.3.1")
    implementation("androidx.camera:camera-view:1.3.1")

    implementation("com.google.mediapipe:tasks-vision:0.10.9")

    // ── ZEGO / ZPNs FCM ─────────────────────────────────────
    //
    // 修正：
    // java.lang.ClassNotFoundException:
    // im.zego.zpns_android_plugin_fcm.FCMPushClient
    //
    // ZEGO 官方 offline invitation 範例會加入 Firebase Messaging
    // 與 im.zego:zpns-fcm。
    implementation(
        platform("com.google.firebase:firebase-bom:29.3.1")
    )
    implementation("com.google.firebase:firebase-messaging:21.1.0")
    implementation("im.zego:zpns-fcm:2.8.0")
}
