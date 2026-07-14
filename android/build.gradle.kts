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
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. jni_flutter, pulled in transitively via path_provider_android)
// declare their own Android module with a hardcoded preferred NDK version, set after
// their plugin is applied, so it must be overridden last (afterEvaluate). :app is
// forced to evaluate early via evaluationDependsOn above, so guard against Gradle's
// "already evaluated" error for that one project.
fun Project.pinNdkVersion() {
    extensions.findByType<com.android.build.gradle.BaseExtension>()?.ndkVersion =
        "26.3.11579264"
}
subprojects {
    if (project.state.executed) {
        pinNdkVersion()
    } else {
        afterEvaluate { pinNdkVersion() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
