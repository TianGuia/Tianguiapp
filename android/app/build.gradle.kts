plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystore = System.getenv("TIANGUIA_ANDROID_KEYSTORE")

android {
    namespace = "mx.udg.alumnos.tianguia"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "mx.udg.alumnos.tianguia"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!releaseKeystore.isNullOrBlank()) {
            create("release") {
                storeFile = file(releaseKeystore)
                storePassword = providers.environmentVariable("TIANGUIA_ANDROID_STORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("TIANGUIA_ANDROID_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("TIANGUIA_ANDROID_KEY_PASSWORD").get()
            }
        }
    }

    buildTypes {
        release {
            // Actions proporciona la clave estable; el desarrollo local conserva su firma de prueba.
            signingConfig = signingConfigs.getByName(if (releaseKeystore.isNullOrBlank()) "debug" else "release")
        }
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
