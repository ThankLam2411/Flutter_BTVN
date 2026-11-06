import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "vn.com.bsc.dcahost"
    compileSdk = 36

    defaultConfig {
        applicationId = "vn.com.bsc.dcahost"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        // Chỉ đóng gói ABI cần thiết (emulator x86_64 + máy thật arm64) để APK gọn hơn
        ndk { abiFilters += listOf("x86_64", "arm64-v8a") }
    }

    packaging {
        jniLibs {
            // Vulkan validation layer đi kèm Flutter engine debug (~hàng trăm MB), không cần cho demo
            excludes += "**/libVkLayer_khronos_validation.so"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Demo: ký bằng debug key để cài thử bản release
            signingConfig = signingConfigs.getByName("debug")
        }
        // Flutter Module có 3 biến thể AAR (debug/profile/release) => thêm build type profile
        create("profile") {
            initWith(getByName("debug"))
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

dependencies {
    // Flutter Module dạng AAR: group = androidPackage trong pubspec của module, version mặc định 1.0
    debugImplementation("vn.com.bsc.dca_flutter_module:flutter_debug:1.0")
    "profileImplementation"("vn.com.bsc.dca_flutter_module:flutter_profile:1.0")
    releaseImplementation("vn.com.bsc.dca_flutter_module:flutter_release:1.0")

    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("androidx.core:core-ktx:1.16.0")
}
