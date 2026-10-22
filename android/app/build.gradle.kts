import java.util.Base64

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
    namespace = "com.corehines.smartbudget"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.corehines.smartbudget"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

// Fail before packaging an unconfigured financial-app entry point. Disposable
// native probes use their own explicit targets and do not launch authentication.
tasks.configureEach {
    if (name.startsWith("compileFlutterBuild")) {
        doFirst {
            val target = project.findProperty("target")?.toString() ?: "lib/main.dart"
            if (target.replace('\\', '/').endsWith("lib/main.dart")) {
                val definitions = mutableMapOf<String, String>()
                try {
                    project.findProperty("dart-defines")?.toString()
                        ?.split(',')?.filter { it.isNotEmpty() }?.forEach {
                            val decoded = String(Base64.getDecoder().decode(it), Charsets.UTF_8)
                            val separator = decoded.indexOf('=')
                            if (separator > 0) {
                                definitions[decoded.substring(0, separator)] = decoded.substring(separator + 1)
                            }
                        }
                } catch (_: IllegalArgumentException) {
                    throw GradleException("Invalid Dart build definitions; values withheld.")
                }
                val debug = name.endsWith("Debug")
                val emulator = definitions["SMARTBUDGET_USE_EMULATORS"] == "true"
                val token = definitions["SMARTBUDGET_APP_CHECK_DEBUG_TOKEN"].orEmpty()
                if (emulator && !debug) {
                    throw GradleException("Authentication emulators are allowed only in debug builds.")
                }
                if (!emulator && definitions["SMARTBUDGET_AUTH_ORIGIN"] !=
                    "https://smartbudget-authorization.corehines-smartbudget.workers.dev") {
                    throw GradleException("Missing approved authorization backend. For the TECNO debug app, run python3 tool/run_debug.py from the repository root.")
                }
                if (!emulator && debug &&
                    !Regex("(?i)^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$").matches(token)) {
                    throw GradleException("Missing registered debug App Check configuration. Run python3 tool/run_debug.py; recover the existing protected configuration rather than generating a token.")
                }
                if (!debug && token.isNotEmpty()) {
                    throw GradleException("Private debug App Check configuration must not be packaged in profile or release builds.")
                }
            }
        }
    }
}

// Native Keystore tests use only disposable scopes and test-specific aliases.
dependencies {
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
