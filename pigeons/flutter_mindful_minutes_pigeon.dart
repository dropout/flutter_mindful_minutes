import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/flutter_mindful_minutes.g.dart',
    kotlinOut:
      'android/src/main/kotlin/dev/adampalinkas/flutter_mindful_minutes/FlutterMindfulMinutesPlugin.g.kt',
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

  @async
  bool isAvailable();

  @async
  AuthorizationStatus getAuthorizationStatus();

  @async
  RequestStatusForAuthorization getRequestForAuthorizationStatus();

  @async
  bool requestAuthorization();

  @async
  bool writeMindfulMinutes(int startSeconds, int endSeconds);

}
