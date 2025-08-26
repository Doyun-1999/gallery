import com.android.build.api.dsl.CommonExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

//android {
//    signingConfigs {
//        create("debug") {
//            storeFile = file(System.getProperty("user.home") + "/.android/debug.keystore")
//            storePassword = "android"
//            keyAlias = "androiddebugkey"
//            keyPassword = "android"
//        }
//        // release는 key.properties 읽어서 세팅
//        create("release") {
//            val keystorePropertiesFile = rootProject.file("key.properties")
//            val keystoreProperties = java.util.Properties()
//            if (keystorePropertiesFile.exists()) {
//                keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
//                storeFile = file(keystoreProperties["storeFile"]!!)
//                storePassword = keystoreProperties["storePassword"] as String
//                keyAlias = keystoreProperties["keyAlias"] as String
//                keyPassword = keystoreProperties["keyPassword"] as String
//            }
//        }
//    }
//
//    buildTypes {
//        getByName("debug") {
//            signingConfig = signingConfigs.getByName("debug")
//        }
//        getByName("release") {
//            signingConfig = signingConfigs.getByName("release")
//            isMinifyEnabled = false
//        }
//    }
//}