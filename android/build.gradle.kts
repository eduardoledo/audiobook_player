allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
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
    
    configurations.all {
        resolutionStrategy {
            eachDependency {
                if (requested.group == "com.github.NanoHttpd.nanohttpd" && requested.name == "nanohttpd") {
                    useTarget("org.nanohttpd:nanohttpd:2.3.1")
                }
                if (requested.group == "com.github.NanoHttpd.nanohttpd" && requested.name == "nanohttpd-nanolets") {
                    useTarget("org.nanohttpd:nanohttpd-nanolets:2.3.1")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
