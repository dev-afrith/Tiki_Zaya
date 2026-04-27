plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.afrith.tikizaya"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.afrith.tikizaya"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes.add("/google/protobuf/**")
            excludes.add("**/*.proto")
            excludes.add("**/tika-mimetypes.xml")
            excludes.add("**/tika-parsers.xml")
            excludes.add("**/publicsuffixes.gz")
            excludes.add("**/kotlin-tooling-metadata.json")
        }
        jniLibs {
            excludes.add("lib/x86_64/**")
            excludes.add("lib/x86/**")
            excludes.add("lib/armeabi-v7a/**")
        }
    }
}

flutter {
    source = "../.."
}
