# VS Code Android project imports

Open `D:\Projects\bthere-mobile` as the VS Code workspace root. The shared
`.vscode/settings.json` is deliberately tracked; personal launch configurations
and other editor files remain ignored.

## Java notifications on opening the repository

The installed Oracle Java extension (27.0.0) uses NetBeans to discover Gradle
projects. Its default project search roots include the user's home directory.
The local Java server log confirms that it attempted to load Pub-cache plugin
folders, including `image_picker_android` and `geolocator`, as standalone Gradle
roots. These modules belong to the Flutter app's Gradle build, rather than being
independent applications. Importing them separately caused the reported
`com.android.library` resolution error.

The workspace sets `jdk.serverVmOptions` to
`-Dproject.limitScanRoot=${workspaceFolder}`. The installed extension expands
the workspace variable and appends this option after its default scan-root
option. This restricts project ownership discovery to this repository instead
of the external Pub cache. Both app Android roots remain inside the allowed
tree. Search and file watching also exclude generated build/cache directories,
and search does not follow plugin symlinks.

This configuration targets Oracle Java, the extension identified in the logs.
Settings for a different Java extension would not fix Oracle's import behavior.
Do not modify plugin files in the Pub cache or add arbitrary Android plugin
versions to those files.

During verification, the extension restarted after the settings change. The
running JVM's effective `project.limitScanRoot` was checked and matched
`D:\Projects\bthere-mobile`; the restarted server log contained no recurrence of
the reported standalone plugin configuration failures. Reopening the editor in
a future session still needs an interactive check.

If an old notification or imported project remains after applying the settings,
clear the existing imported-project cache once:

1. Open the Command Palette (`Ctrl+Shift+P`).
2. Run **Delete Oracle Java extension cache for this workspace**.
3. Follow the command's reload prompt; otherwise run **Developer: Reload Window**.

This removes stale editor imports. It does not remove Flutter dependencies,
application data, or the Gradle build cache. Actual interactive editor reopening
must be checked in VS Code; a successful APK build alone does not prove that
the language server has discarded its previously imported projects.

References: [Oracle Java configuration and workspace-cache command](https://github.com/oracle/javavscode),
[NetBeans scan-root property](https://bits.netbeans.org/27/javadoc/properties.html).

## If Oracle Java notifications persist

The scan boundary is not a complete compatibility fix for the Oracle Java
Gradle importer. Later screenshots also show its generated `nb-tooling.gradle`
failing with `Unsupported class file major version 65`, and a
`SelfResolvingDependency` linkage error. These are editor tooling failures;
both real Flutter debug APK builds passed with the app Gradle wrappers.
Changing application plugin versions to accommodate the editor is not warranted.

For Flutter development in this repository, disable **Java by Oracle**
(`Oracle.oracle-java`) **for this workspace only**:

1. Open Extensions (`Ctrl+Shift+X`) and search `@id:Oracle.oracle-java`.
2. Open its gear/menu and choose **Disable (Workspace)**.
3. Run **Developer: Reload Window** from the Command Palette.
4. Clear existing notifications. Reopen the same repository root to check that
   no new Oracle Java import notifications appear.

VS Code retains this choice for the workspace. Dart/Flutter editing, Flutter
terminal commands and Android APK builds remain available; Oracle Java language
features are disabled here. Use Android Studio when native Android IDE support
is needed. Other Java workspaces are unaffected.

This action must be performed in the VS Code UI. There is no ordinary repository
`settings.json` key that disables an installed extension for a workspace. Do not
claim that search exclusions or an extension recommendation disable it, and do
not edit VS Code's internal state database to simulate that action.

Reference: [VS Code extension disable controls](https://code.visualstudio.com/docs/configure/extensions/extension-marketplace).

## Kotlin incremental cache errors on Windows

Both apps set `kotlin.incremental=false` in their Android `gradle.properties`.
The Pub cache on C: and repository on D: previously caused Kotlin incremental
cache path conversion failures. Persisting this setting avoids having to set
`GRADLE_OPTS` in each terminal. Full Kotlin compilation may take longer; runtime
application behavior is unchanged.

From the Customer app directory, use the normal command:

```powershell
flutter run --dart-define=BTHERE_API_BASE_URL=https://jobhub.pentarixlabs.com/api/v1
```

Backend HTTP failures, including `/customers/me/services` returning 500 and
uploaded photo URLs returning 403, are separate from these editor/build issues.
