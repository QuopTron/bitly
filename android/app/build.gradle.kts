plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bitly"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    repositories {
        flatDir { dirs("libs") }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.bitly"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

afterEvaluate {
    // Build ALL real device ABIs (incl. armeabi-v7a for low/mid-range 32-bit
    // phones) in one universal APK, overriding Flutter's default single-ABI.
    android.buildTypes.forEach { buildType ->
        buildType.ndk.abiFilters.clear()
        buildType.ndk.abiFilters.add("armeabi-v7a")
        buildType.ndk.abiFilters.add("arm64-v8a")
        buildType.ndk.abiFilters.add("x86_64")
    }
}

dependencies {
    implementation(files("libs/bitly.aar"))
    implementation("androidx.window:window:1.3.0")
    implementation("androidx.window:window-java:1.3.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
