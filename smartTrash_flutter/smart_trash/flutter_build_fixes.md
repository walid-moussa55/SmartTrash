# Flutter Android Build Fixes

---

## Fix 1: Missing Flutter Engine Artifacts

**Issue:** `flutter build apk` fails with:
```
Could not find io.flutter:armeabi_v7a_release
```

**The Cause:**
In newer versions of Flutter (like 3.41), the Gradle plugin dynamically injects `https://storage.googleapis.com/download.flutter.io` as a Maven repository to download the core Flutter engine. However, your `android/settings.gradle.kts` file had `repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)` configured. This strict setting blocks Gradle from using any repositories that plugins (like Flutter's) dynamically add, resulting in Gradle not knowing where to download the Flutter engine.

**Fix:** Manually add the Flutter download URL to `android/settings.gradle.kts`:

```kotlin
// android/settings.gradle.kts
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

## Fix 2: JitPack Timeout (osmbonuspack)

**Issue:** `flutter build apk` fails with:
```
Could not get resource 'https://jitpack.io/com/github/MKergall/osmbonuspack/6.9.0/osmbonuspack-6.9.0.aar'
> Read timed out
```

**The Cause:**
The `flutter_osm_plugin` relies on an Android library called `osmbonuspack` which is hosted on JitPack. JitPack is notoriously unreliable and frequently times out or goes offline, completely blocking the build. 

**The Fix:**
We bypassed JitPack entirely by downloading the required `.aar` file manually and setting up a "Local Maven Repository" inside your project folder.

**Step 1. Create the Local Directory Structure**
Inside your project's `android` folder, create the exact folder structure that Maven expects for this specific library version (`6.9.0`):
```powershell
mkdir android\local_m2\com\github\MKergall\osmbonuspack\6.9.0
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
// android/settings.gradle.kts
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
**Step 4. Build**
```powershell
flutter build apk
```
