plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Set INCLUDE_X86_64=true to keep the emulator-only ABI in the APK (useful
// for testing on x86_64 emulators that can't run arm64 via translation).
// Default: phone-only build (armeabi-v7a + arm64-v8a).
val includeX86_64: Boolean = System.getenv("INCLUDE_X86_64") == "true"

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

    packagingOptions {
        jniLibs {
            // Compress native libs inside the APK (instead of storing them
            // page-aligned/uncompressed). Cuts APK size roughly in half; libs
            // are extracted at install time, which is fine for sideloaded APKs.
            useLegacyPackaging = true
            // Phone ABIs only by default. Exclude x86_64 (emulator-only) at
            // packaging time: this is the one mechanism that reliably drops
            // third-party native libs (ffmpeg-kit, media_kit/mpv, the Go .aar)
            // for that ABI even though the Flutter plugin's abiFilters leave
            // them merged. INCLUDE_X86_64=true keeps them for emulator testing.
            if (!includeX86_64) {
                excludes += "lib/x86_64/**"
            }
        }
    }

    // Split per-ABI: instead of one fat APK carrying every architecture's
    // native libs (libgojni ~18MB + libmpv ~12MB + ffmpeg ~25MB + flutter/app
    // ~20MB EACH), `flutter build apk --split-per-abi` emits one slim APK per
    // ABI (~40MB) — each user downloads only their device's libs. The universal
    // APK remains available via --universal-apk for sideloading everywhere.
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a")
            if (includeX86_64) {
                include("x86_64")
            }
            isUniversalApk = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // Minify/shrink breaks the native Go backend bridge (bitly.aar) and
            // ffmpeg-kit's JNI registration, leaving the app stuck on the splash
            // screen in release builds. Disabled so release behaves like debug.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
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
