import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key cho Google Play: android/key.properties (đã .gitignore, xem key.properties.example).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) FileInputStream(keystorePropertiesFile).use { load(it) }
}
val hasUploadKey = keystorePropertiesFile.exists()

android {
    namespace = "com.panelforge.reader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.14904198"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.panelforge.reader"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Có key.properties → ký bằng upload key. Chưa có → ký debug để `flutter run --release` vẫn chạy
            // trên máy; riêng gói AAB gửi Google Play (bundleRelease) bị chặn bên dưới.
            signingConfig = if (hasUploadKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

// `--dart-define` Flutter chuyển sang Gradle dạng base64, ngăn cách bằng dấu phẩy.
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { runCatching { String(Base64.getDecoder().decode(it)) }.getOrNull() }
    ?.mapNotNull { def -> def.indexOf('=').takeIf { it > 0 }?.let { def.substring(0, it) to def.substring(it + 1) } }
    ?.toMap()
    ?: emptyMap()

// Chốt chặn cho gói gửi Google Play (bundleRelease):
// - phải ký bằng upload key (Play từ chối debug key, và lỡ phát hành thì không cập nhật được);
// - phải có API_BASE_URL https (không có thì app trỏ vào 10.0.2.2 — chỉ chạy trên emulator).
gradle.taskGraph.whenReady {
    if (allTasks.none { it.project == project && it.name == "bundleRelease" }) return@whenReady
    if (!hasUploadKey) {
        throw GradleException(
            "Thiếu android/key.properties: gói Google Play phải ký bằng upload key. " +
                "Xem android/key.properties.example."
        )
    }
    val apiBaseUrl = dartDefines["API_BASE_URL"].orEmpty().trim()
    if (!apiBaseUrl.startsWith("https://")) {
        throw GradleException(
            "Gói Google Play cần máy chủ production: " +
                "flutter build appbundle --release --dart-define=API_BASE_URL=https://<máy chủ>"
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
