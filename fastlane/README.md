fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios build

```sh
[bundle exec] fastlane ios build
```

Build iOS release for device install (no upload)

### ios notes

```sh
[bundle exec] fastlane ios notes
```

Update TestFlight 'What to Test' notes for a specific build

### ios device

```sh
[bundle exec] fastlane ios device
```

Install on connected device

----


## Android

### android build_apk

```sh
[bundle exec] fastlane android build_apk
```

Build APK

### android beta

```sh
[bundle exec] fastlane android beta
```

Build App Bundle and upload to Play Store (internal track)

### android apk

```sh
[bundle exec] fastlane android apk
```

Build APK and copy to Downloads

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
