## 0.3.0

* Updates the minimum supported SDK versions to Dart 3.12 and Flutter 3.44.
* Migrates the Android plugin and example app to built-in Kotlin.

## 0.2.0

* **Breaking:** `isAvailable()` is replaced by `checkAvailability()`, which completes normally when mindful minutes can be used and throws a `MindfulMinutesUnavailableException` subtype describing the reason otherwise.
* **Breaking:** all methods now throw typed `FlutterMindfulMinutesException` subtypes instead of `PlatformException`.
* iOS: a missing HealthKit entitlement is reported as `MissingEntitlementException` instead of an unreadable `PlatformException`.
* Android: a missing `WRITE_MINDFULNESS` manifest declaration is reported as `MissingPermissionDeclarationException`, and a `MainActivity` that doesn't extend `FlutterFragmentActivity` as `ActivityNotSupportedException`.
* Regenerated platform code with Pigeon 28 (using `@asyncCallback` to keep callback-style native APIs).

## 0.0.1

* TODO: Describe initial release.
