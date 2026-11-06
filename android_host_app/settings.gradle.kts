pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // AAR của Flutter Module (output của: dca_flutter_module/tool/build_aar.sh)
        maven(url = uri("../dca_flutter_module/build/host/outputs/repo"))
        // Flutter engine artifacts (io.flutter:flutter_embedding_*, arm64_v8a_*, x86_64_*)
        maven(url = uri("https://storage.googleapis.com/download.flutter.io"))
    }
}

rootProject.name = "DcaHost"
include(":app")
