import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

fun keyProperty(name: String): String? =
    keyProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

val releaseStoreFile = keyProperty("storeFile")
val releaseStorePassword = keyProperty("storePassword")
val releaseKeyAlias = keyProperty("keyAlias")
val releaseKeyPassword = keyProperty("keyPassword")
val hasReleaseKeystore = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

android {
    namespace = "org.hmg.spy_love"
    // permission_handler_android 14 requires API 37. The published platform
    // package is platforms;android-37.0 (directory android-37.0), so the minor
    // level must be set. compileSdk = 37 alone looks for platforms/android-37.
    compileSdk = 37
    compileSdkMinor = 0
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                // storeFile is resolved from the android/ directory (rootProject).
                storeFile = rootProject.file(checkNotNull(releaseStoreFile))
                storePassword = checkNotNull(releaseStorePassword)
                keyAlias = checkNotNull(releaseKeyAlias)
                keyPassword = checkNotNull(releaseKeyPassword)
            }
        }
    }

    defaultConfig {
        applicationId = "org.hmg.spy_love"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // With a keystore, debug matches the release cert (Google Sign-In SHA-1).
            // Without one, the default debug keystore is left in place so local
            // builds do not fail on an empty signing config.
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        release {
            // Only assign a release signingConfig when a keystore is present.
            // Assembling release without one fails in whenReady below — never
            // fall back to the debug keystore.
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Fail any Release assemble/bundle when key.properties is missing.
// Do not silently sign with the debug keystore.
gradle.taskGraph.whenReady {
    val assemblingRelease = allTasks.any { task ->
        task.project == project &&
            task.name.contains("Release", ignoreCase = false)
    }
    if (assemblingRelease && !hasReleaseKeystore) {
        throw org.gradle.api.GradleException(
            "Release signing requires android/key.properties with storeFile, " +
                "storePassword, keyAlias, and keyPassword. " +
                "Refusing to fall back to the debug keystore.",
        )
    }
}
