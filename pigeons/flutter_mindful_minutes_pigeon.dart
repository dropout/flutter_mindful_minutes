import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/flutter_mindful_minutes.g.dart',
    kotlinOut:
      'android/src/main/kotlin/dev/adampalinkas/flutter_mindful_minutes/FlutterMindfulMinutesPlugin.g.kt',
    kotlinOptions: KotlinOptions(
      errorClassName: 'FlutterMindfulMinutesPluginError'
    ),
    swiftOut: 'ios/flutter_mindful_minutes/Sources/flutter_mindful_minutes/FlutterMindfulMinutesPlugin.g.swift',
    dartPackageName: 'flutter_mindful_minutes',
  )
)

enum AuthorizationStatus {
  denied,
  notDetermined,
  authorized,
  unknown,
}

enum RequestStatusForAuthorization {
  shouldRequest,
  unnecessary,
  unknown,
}

class AuthorizationResult {
  final bool success;
  final AuthorizationStatus status;
  const AuthorizationResult({
    required this.success,
    required this.status,
  });
}

@HostApi()
abstract class FlutterMindfulMinutesHostApi {

  /// Completes normally when mindful minutes can be used on this device,
  /// otherwise fails with a coded error describing the reason.
  @asyncCallback
  void checkAvailability();

  @asyncCallback
  AuthorizationStatus getAuthorizationStatus();

  @asyncCallback
  RequestStatusForAuthorization getRequestForAuthorizationStatus();

  @asyncCallback
  bool requestAuthorization();

  @asyncCallback
  bool writeMindfulMinutes(int startSeconds, int endSeconds);

}
