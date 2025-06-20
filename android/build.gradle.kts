plugins {
    // For your Android application module
    id("com.android.application") version "8.10.0" apply false // Apply the AGP for app modules

    // If you have Android library modules, add this too:
    // id("com.android.library") version "8.10.0" apply false

    // If you're using Kotlin for Android development (which is highly likely)
    // Make sure to include the Kotlin Android plugin. Find its appropriate version.
    // Example: (Check the latest compatible version for AGP 8.10.0)
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false // Or your current Kotlin version
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

