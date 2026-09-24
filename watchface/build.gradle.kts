plugins {
    alias(libs.plugins.android.application)
}

android {
    // Watch Face Format packages are resource-only; no Kotlin/Java sources.
    enableKotlin = false
    namespace = "com.mikehildner.co5watchface"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.mikehildner.co5watchface"
        // Watch Face Format v2 requires Wear OS 5 (API 34) or later.
        minSdk = 34
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        debug {
            isMinifyEnabled = true
        }
        release {
            // TODO: add a real signingConfig before publishing.
            isMinifyEnabled = true
            // Resources are the whole watch face; never shrink them away.
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
