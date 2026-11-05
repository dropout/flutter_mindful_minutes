import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// Error codes sent by the native side of the plugin.
///
/// They have to match the codes used in the Swift and Kotlin implementations.
@internal
abstract final class MindfulMinutesErrorCodes {
  static const healthDataUnavailable = 'health_data_unavailable';
  static const providerUpdateRequired = 'provider_update_required';
  static const mindfulnessNotSupported = 'mindfulness_not_supported';
  static const activityNotSupported = 'activity_not_supported';
  static const missingEntitlement = 'missing_entitlement';
  static const missingPermissionDeclaration = 'missing_permission_declaration';
}

/// Base class of every exception thrown by the plugin.
///
/// It is sealed, so a `switch` over it can be checked for exhaustiveness.
sealed class FlutterMindfulMinutesException implements Exception {
  const FlutterMindfulMinutesException(this.message, {this.details});

  /// Human readable description of the problem, provided by the platform.
  final String? message;

  /// Additional platform specific information (e.g. the original native error).
  final Object? details;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown by [FlutterMindfulMinutes.checkAvailability] when mindful minutes
/// can't be used on the current device. Subtypes describe the reason.
sealed class MindfulMinutesUnavailableException
    extends FlutterMindfulMinutesException {
  const MindfulMinutesUnavailableException(super.message, {super.details});
}

/// The health data store is not available on the device.
///
/// - iOS: HealthKit is not available (e.g. on some iPads).
/// - Android: the Health Connect SDK is not available on the device.
///
/// On iOS the other methods of the plugin throw it as well when called on
/// such a device.
class HealthDataUnavailableException extends MindfulMinutesUnavailableException {
  const HealthDataUnavailableException(super.message, {super.details});
}

/// Android only: the Health Connect provider has to be installed or updated.
class ProviderUpdateRequiredException
    extends MindfulMinutesUnavailableException {
  const ProviderUpdateRequiredException(super.message, {super.details});
}

/// Android only: Health Connect on this device does not support mindfulness
/// sessions yet (updating Google Play services may help).
class MindfulnessNotSupportedException
    extends MindfulMinutesUnavailableException {
  const MindfulnessNotSupportedException(super.message, {super.details});
}

/// Android only: the app's `MainActivity` does not extend
/// `FlutterFragmentActivity`, so the permission UI can't be launched.
class ActivityNotSupportedException extends MindfulMinutesUnavailableException {
  const ActivityNotSupportedException(super.message, {super.details});
}

/// iOS only: the HealthKit capability (`com.apple.developer.healthkit`
/// entitlement) is not enabled for the app's target in Xcode.
class MissingEntitlementException extends FlutterMindfulMinutesException {
  const MissingEntitlementException(super.message, {super.details});
}

/// Android only: the `android.permission.health.WRITE_MINDFULNESS`
/// permission is not declared in the app's `AndroidManifest.xml`.
class MissingPermissionDeclarationException
    extends FlutterMindfulMinutesException {
  const MissingPermissionDeclarationException(super.message, {super.details});
}

/// Any other error reported by the platform.
class UnknownMindfulMinutesException extends FlutterMindfulMinutesException {
  const UnknownMindfulMinutesException(
    this.code,
    super.message, {
    super.details,
  });

  /// The raw error code reported by the platform.
  final String code;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// Converts a [PlatformException] coming from the native side to the
/// matching [FlutterMindfulMinutesException].
@internal
FlutterMindfulMinutesException mapPlatformException(PlatformException e) {
  final message = e.message;
  final details = e.details;
  return switch (e.code) {
    MindfulMinutesErrorCodes.healthDataUnavailable =>
      HealthDataUnavailableException(message, details: details),
    MindfulMinutesErrorCodes.providerUpdateRequired =>
      ProviderUpdateRequiredException(message, details: details),
    MindfulMinutesErrorCodes.mindfulnessNotSupported =>
      MindfulnessNotSupportedException(message, details: details),
    MindfulMinutesErrorCodes.activityNotSupported =>
      ActivityNotSupportedException(message, details: details),
    MindfulMinutesErrorCodes.missingEntitlement =>
      MissingEntitlementException(message, details: details),
    MindfulMinutesErrorCodes.missingPermissionDeclaration =>
      MissingPermissionDeclarationException(message, details: details),
    _ => UnknownMindfulMinutesException(e.code, message, details: details),
  };
}
