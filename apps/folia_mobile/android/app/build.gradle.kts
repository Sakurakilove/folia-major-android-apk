import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = System.getenv("FOLIA_RELEASE_PROPERTIES")?.let { File(it) }
val deliveryProperties = Properties().apply {
    if (releasePropertiesFile?.isFile == true) releasePropertiesFile.inputStream().use { load(it) }
}

android {
    namespace = "top.izuna.foliamajor.next"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "top.izuna.foliamajor.next"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releasePropertiesFile?.isFile == true) {
            create("delivery") {
                val configured = File(deliveryProperties.getProperty("storeFile"))
                storeFile = if (configured.isAbsolute) configured else File(releasePropertiesFile.parentFile, "app").resolve(configured)
                storePassword = deliveryProperties.getProperty("storePassword")
                keyAlias = deliveryProperties.getProperty("keyAlias")
                keyPassword = deliveryProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Release credentials are provided externally; never package a debug-signed delivery.
            signingConfig = signingConfigs.findByName("delivery")
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

dependencies {
    implementation("androidx.media3:media3-exoplayer:1.11.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.11.1")
}
