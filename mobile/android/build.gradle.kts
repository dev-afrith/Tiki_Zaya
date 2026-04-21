import groovy.lang.GroovyObject

plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android is GroovyObject) {
            try {
                val currentNamespace = android.getProperty("namespace") as String?
                if (currentNamespace.isNullOrBlank()) {
                    val manifest = file("src/main/AndroidManifest.xml")
                    if (manifest.exists()) {
                        val pkg = Regex("package\\s*=\\s*\"([^\"]+)\"")
                            .find(manifest.readText())
                            ?.groupValues
                            ?.getOrNull(1)
                        if (!pkg.isNullOrBlank()) {
                            android.setProperty("namespace", pkg)
                        }
                    }
                }
            } catch (_: Exception) {
                // Ignore modules/extensions that do not expose namespace
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
