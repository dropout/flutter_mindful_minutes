import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/flutter_mindful_minutes.g.dart',
    kotlinOut:
      'android/src/main/kotlin/dev/adampalinkas/flutter_mindful_minutes/FlutterMindfulMinutesPlugin.g.kt',
    swiftOut: 'ios/Classes/FlutterMindfulMinutesPlugin.g.swift',
    dartPackageName: 'flutter_mindful_minutes',
  )
)

@HostApi()
abstract class FlutterMindfulMinutesHostApi {

  @async
  bool isAvailable();

  @async
  bool hasPermission();

  @async
  bool requestPermission();

  @async
  bool writeMindfulMinutes(int startSeconds, int endSeconds);

}
