# Flutter Android Build Error Resolutions

During our session, we encountered two completely separate build errors that prevented `flutter build apk` from succeeding. 

Here is the exact step-by-step documentation of what went wrong and how we fixed them, so you can apply these fixes to any future projects or if you clone this project onto a new machine.

---

## 🛑 Error 1: Missing Flutter Engine Artifacts
**The Error Message:**
```text
Could not find io.flutter:armeabi_v7a_release
Searched in the following locations: google, mavenCentral, jitpack...
```

**The Cause:**
In newer versions of Flutter (like 3.41), the Gradle plugin dynamically injects `https://storage.googleapis.com/download.flutter.io` as a Maven repository to download the core Flutter engine. However, your `android/settings.gradle.kts` file had `repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)` configured. This strict setting blocks Gradle from using any repositories that plugins (like Flutter's) dynamically add, resulting in Gradle not knowing where to download the Flutter engine.

**The Fix:**
You must manually declare the Flutter download server inside `dependencyResolutionManagement` in `android/settings.gradle.kts`.

1. Open `android/settings.gradle.kts`.
2. Find the `dependencyResolutionManagement { repositories { ... } }` block.
3. Add the `download.flutter.io` URL to the list:
```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
        
        // ADD THIS: Required for Flutter engine artifacts
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}
```

---

## 🛑 Error 2: JitPack Network Timeout
**The Error Message:**
```text
Could not get resource 'https://jitpack.io/com/github/MKergall/osmbonuspack/6.9.0/osmbonuspack-6.9.0.aar'.
> Read timed out
```

**The Cause:**
The `flutter_osm_plugin` relies on an Android library called `osmbonuspack` which is hosted on JitPack. JitPack is notoriously unreliable and frequently times out or goes offline, completely blocking the build. 

**The Fix:**
We bypassed JitPack entirely by downloading the required `.aar` file manually and setting up a "Local Maven Repository" inside your project folder.

**Step 1. Create the Local Directory Structure**
Inside your project's `android` folder, create the exact folder structure that Maven expects for this specific library version (`6.9.0`):
```text
android/local_m2/com/github/MKergall/osmbonuspack/6.9.0/
```

**Step 2. Download the Files manually**
Download the required `.aar` file and its `.pom` metadata file from the original creator's GitHub Releases page, and place them into the folder you just created:
* Download from: [https://github.com/MKergall/osmbonuspack/releases/tag/6.9.0](https://github.com/MKergall/osmbonuspack/releases/tag/6.9.0)
* Ensure the files are named exactly:
  * `osmbonuspack-6.9.0.aar`
  * `osmbonuspack-6.9.0.pom`

**Step 3. Tell Gradle to use your Local Repository**
Open `android/settings.gradle.kts` and add your new local folder to the **very top** of the repositories block, so Gradle checks there *before* trying the internet.

```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        // ADD THIS AT THE TOP: Intercepts the JitPack request and serves locally
        maven { url = uri("${settingsDir.absolutePath}/local_m2") }
        
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}
```

By doing this, Gradle finds `osmbonuspack` on your hard drive instantly and never even attempts to contact JitPack.io.
