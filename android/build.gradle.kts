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

// just_audio only calls DefaultHttpDataSource.Factory.setUserAgent when the
// source map already contains User-Agent. Install the IAB agent first so
// outbound .mp3 requests are not sent as "just_audio".
subprojects {
    if (name != "just_audio") return@subprojects
    val source = project.file("src/main/java/com/ryanheise/just_audio/AudioPlayer.java")
    if (!source.exists()) return@subprojects
    val text = source.readText()
    if (text.contains("PELEVO_EXO_USER_AGENT")) return@subprojects
    val newline = if (text.contains("\r\n")) "\r\n" else "\n"
    val needle =
        "        if (userAgent == null) {$newline" +
            "            userAgent = Util.getUserAgent(context, \"just_audio\");$newline" +
            "        }"
    if (!text.contains(needle)) {
        throw GradleException(
            "just_audio AudioPlayer.java no longer matches the Pelevo User-Agent patch. " +
                "Update android/build.gradle.kts.",
        )
    }
    val replacement =
        "        // PELEVO_EXO_USER_AGENT: Media3 DefaultHttpDataSource.Factory.setUserAgent.$newline" +
            "        String pelevoAgent = null;$newline" +
            "        try {$newline" +
            "            Class<?> agentClass = Class.forName(\"com.podemeraldltd.pelevo.PelevoExoUserAgent\");$newline" +
            "            Object agentValue = agentClass.getMethod(\"get\").invoke(null);$newline" +
            "            if (agentValue instanceof String) {$newline" +
            "                pelevoAgent = (String) agentValue;$newline" +
            "            }$newline" +
            "        } catch (Throwable ignored) {$newline" +
            "        }$newline" +
            "        if (pelevoAgent != null && !pelevoAgent.isEmpty()) {$newline" +
            "            userAgent = pelevoAgent;$newline" +
            "        } else if (userAgent == null) {$newline" +
            "            userAgent = Util.getUserAgent(context, \"just_audio\");$newline" +
            "        }"
    source.writeText(text.replace(needle, replacement))
    logger.lifecycle("Pelevo: attached IAB User-Agent to just_audio ExoPlayer HTTP data source")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
