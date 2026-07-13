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

### ios build

```sh
[bundle exec] fastlane ios build
```

Build the release IPA via `flutter build ipa`

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload a new beta build to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and submit a new build to App Store review

### ios verify_auth

```sh
[bundle exec] fastlane ios verify_auth
```

TEMP: verify App Store Connect API key auth only

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
