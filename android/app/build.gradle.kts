import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// CI writes android/key.properties and android/app/upload-keystore.jks from
// repository secrets before a signed build. Read it when present; a checkout
// without it (a guest clone, or a plain `flutter run --release`) keeps working
// on the debug key instead of failing to configure.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.keshabstudios.grammarbondhu"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play Store application ID — never change after publishing.
        applicationId = "com.keshabstudios.grammarbondhu"
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
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // The upload key lives in android/key.properties (git-ignored, written
            // by CI from secrets). Without it the release build falls back to the
            // debug key so the app still runs — never ship such an artifact.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // AGP 9 turns on R8 for release builds. Our plugins reach their Java
            // side through JNI (shared_preferences → the `jni` package, Pigeon
            // registrars like SharedPreferencesApiRegistrar), so nothing in the
            // Java bytecode references those methods — R8 strips them and the
            // release app dies before the first frame with:
            //   NoSuchMethodError: no non-static method
            //   "...SharedPreferencesApiRegistrar;.getAll(...)"
            // The plugins ship no consumer ProGuard rules, so shrinking stays off
            // (the Flutter template default). Dart is AOT-compiled either way, and
            // a store build uses an AAB, so the size cost is small.
            isMinifyEnabled = false
            isShrinkResources = false
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
