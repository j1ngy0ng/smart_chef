import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

dependencies {
    implementation("androidx.credentials:credentials:1.6.0-rc01")
    implementation("androidx.credentials:credentials-play-services-auth:1.6.0-rc01")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.2.0")
}

android {
    namespace = "com.smart_chef.smart_chef"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    val hasReleaseSigningConfig = keystorePropertiesFile.exists()
    if (hasReleaseSigningConfig) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }
    val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
        it.contains("Release", ignoreCase = true)
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.smart_chef.smart_chef"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            } else if (isReleaseBuildRequested) {
                throw GradleException(
                    "Missing android/key.properties for release signing. " +
                    "Create it locally and provide storeFile, storePassword, keyAlias, keyPassword."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
