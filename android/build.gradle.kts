buildscript {
    repositories {
        google()       // Repository for Google-provided artifacts
        mavenCentral() // General repository
        // You might need other repositories depending on the plugins you use
    }
    dependencies {
        // Example: Adding the Google Services plugin
        // Replace with the actual latest version if needed
        classpath("com.google.gms:google-services:4.4.3") // Or the latest version like 4.3.15, 4.4.0, etc.

        // If you were also adding the Kotlin plugin here (though it's often in settings.gradle.kts now):
        // classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.20") // Example
    }
}

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
