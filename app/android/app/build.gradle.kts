import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Firma de release ─────────────────────────────────────────────
// Ver docs/FIRMA.md. Nunca se commitea un keystore ni una contraseña:
// las credenciales llegan por variables de entorno (build en Docker)
// o por un key.properties fuera del repo (dev local).
//
// tools/build.sh ya frena ANTES de invocar Gradle si faltan las
// credenciales de release, con un mensaje explícito — por eso acá no
// hace falta (ni conviene) fallar la evaluación: Gradle procesa este
// bloque para CUALQUIER variante, así que lanzar una excepción acá
// rompería también los builds de debug sin necesidad.
val keystorePropertiesFile = File(
    System.getenv("FWI_KEY_PROPERTIES")
        ?: "${System.getProperty("user.home")}/.secrets/fwi-lanin/key.properties"
)
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(keystorePropertiesFile.inputStream())
}

fun signingValue(envKey: String, propKey: String): String? =
    System.getenv(envKey) ?: keystoreProperties.getProperty(propKey)

val releaseKeystorePath = signingValue("FWI_KEYSTORE_PATH", "storeFile")

android {
    namespace = "com.flet.fwi_lanin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.flet.fwi_lanin"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeystorePath != null) {
            create("release") {
                storeFile = file(releaseKeystorePath)
                storePassword = signingValue("FWI_KEYSTORE_PASSWORD", "storePassword")
                keyAlias = signingValue("FWI_KEY_ALIAS", "keyAlias")
                keyPassword = signingValue("FWI_KEY_PASSWORD", "keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Con credenciales (env vars o key.properties externo): firma real.
            // Sin ellas: cae a la firma de debug, igual que el scaffold por
            // defecto de Flutter — así `flutter run --release` sigue andando
            // para pruebas locales. tools/build.sh es quien impide que un AAB
            // sin firma real llegue a producción (ver docs/FIRMA.md).
            signingConfig = if (releaseKeystorePath != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
