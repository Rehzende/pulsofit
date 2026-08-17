import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.pulsofit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            val keyPropsFile = rootProject.file("key.properties")
            val keyProps = Properties()
            if (keyPropsFile.exists()) keyProps.load(keyPropsFile.inputStream())
            keyAlias = keyProps.getProperty("keyAlias") ?: "pulso"
            keyPassword = keyProps.getProperty("keyPassword") ?: System.getenv("KEYSTORE_PASSWORD") ?: ""
            storeFile = file("keystore/pulso-release.jks")
            storePassword = keyProps.getProperty("storePassword") ?: System.getenv("KEYSTORE_PASSWORD") ?: ""
        }
    }

    defaultConfig {
        applicationId = "app.pulsofit"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            // Enable R8 minification, obfuscation, and optimization
            isMinifyEnabled = true
            
            // Enable resource shrinking (removes unused resources)
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
