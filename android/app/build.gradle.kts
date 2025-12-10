import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties file
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.stoppr.sugar.app"
    compileSdk = 35
    ndkVersion = "27.0.12077973"
    buildToolsVersion = "35.0.1" // Using available 35.0.1 instead of corrupted 35.0.0

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.stoppr.sugar.app"
        minSdk = 26 // Required by superwallkit_flutter plugin
        targetSdk = 35 // Latest Android version
        versionCode = 131
        versionName = "7.4.2"
        multiDexEnabled = true

        // Kotlin DSL: assign manifest placeholders via map access
        // APPSFLYER_DEV_KEY must be set as environment variable - no hardcoded fallback
        val appsflyerDevKey = System.getenv("APPSFLYER_DEV_KEY")
        if (appsflyerDevKey.isNullOrEmpty()) {
            throw GradleException("APPSFLYER_DEV_KEY environment variable is required. Set it in your .env file or export it before building.")
        }
        manifestPlaceholders["APPSFLYER_DEV_KEY"] = appsflyerDevKey
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Using release signing config instead of debug
            signingConfig = signingConfigs.getByName("release")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

// Unify CommonMark to avoid duplicates from Crisp (Markwon) vs RevenueCat UI
configurations.all {
    exclude(group = "com.atlassian.commonmark", module = "commonmark")
    exclude(group = "com.atlassian.commonmark", module = "commonmark-ext-gfm-tables")
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Add window libraries to avoid crashes on Android 12L
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
    // Prefer newer org.commonmark to match purchases-ui
    implementation("org.commonmark:commonmark:0.21.0")
    implementation("org.commonmark:commonmark-ext-gfm-strikethrough:0.21.0")
    implementation("org.commonmark:commonmark-ext-gfm-tables:0.21.0")
}

flutter {
    source = "../.."
}