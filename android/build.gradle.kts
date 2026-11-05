allprojects {
    repositories {
        // Template order only. Unreachable mirrors fail the whole resolve —
        // Gradle does not skip to the next repo on UnknownHost.
        google()
        mavenCentral()
        maven { url = uri("${rootProject.projectDir}/local-maven-repo") }
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

// 16 KB page sizes: ensure plugin CMake/ndk-build links with 16 KB ELF alignment
// (NDK r28 defaults help, but some plugins only set max-page-size).
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withPlugin
        try {
            val defaultConfig =
                androidExt.javaClass.methods
                    .firstOrNull { it.name == "getDefaultConfig" && it.parameterCount == 0 }
                    ?.invoke(androidExt) ?: return@withPlugin
            val externalNativeBuild =
                defaultConfig.javaClass.methods
                    .firstOrNull { it.name == "getExternalNativeBuild" && it.parameterCount == 0 }
                    ?.invoke(defaultConfig) ?: return@withPlugin
            val cmake =
                externalNativeBuild.javaClass.methods
                    .firstOrNull { it.name == "getCmake" && it.parameterCount == 0 }
                    ?.invoke(externalNativeBuild) ?: return@withPlugin
            val arguments =
                cmake.javaClass.methods
                    .firstOrNull { it.name == "getArguments" && it.parameterCount == 0 }
                    ?.invoke(cmake) as? MutableList<String> ?: return@withPlugin
            val flags =
                listOf(
                    "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON",
                    "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384",
                    "-DCMAKE_EXE_LINKER_FLAGS=-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384",
                )
            var added = false
            for (flag in flags) {
                val key = flag.substringBefore("=")
                if (arguments.none { it.startsWith(key) }) {
                    arguments.add(flag)
                    added = true
                }
            }
            if (added) {
                logger.lifecycle("Pelevo: 16 KB page-size linker flags for :${project.name}")
            }
        } catch (_: Exception) {
            // Plugin has no CMake externalNativeBuild — ignore.
        }
    }
}

// jni (via shared_preferences_android) may only set max-page-size; add
// common-page-size so RELRO/LOAD padding matches Play's 16 KB checks.
subprojects {
    if (name != "jni") return@subprojects
    val cmake =
        listOf(
            project.file("src/CMakeLists.txt"),
            project.file("../src/CMakeLists.txt"),
        ).firstOrNull { it.exists() } ?: return@subprojects
    val text = cmake.readText()
    if (text.contains("PELEVO_16KB_PAGE_SIZE")) return@subprojects
    val needle = "\ttarget_link_options(jni PRIVATE \"-Wl,-z,max-page-size=16384\")"
    if (!text.contains(needle)) {
        logger.warn("Pelevo: jni CMakeLists.txt no longer matches 16 KB patch; skip")
        return@subprojects
    }
    val replacement =
        "\t# PELEVO_16KB_PAGE_SIZE\n" +
            "\ttarget_link_options(jni PRIVATE\n" +
            "\t\t\"-Wl,-z,max-page-size=16384\"\n" +
            "\t\t\"-Wl,-z,common-page-size=16384\")"
    cmake.writeText(text.replace(needle, replacement))
    logger.lifecycle("Pelevo: patched jni CMakeLists.txt for 16 KB common-page-size")
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
