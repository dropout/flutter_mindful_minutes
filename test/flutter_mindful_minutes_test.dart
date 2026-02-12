// import 'package:flutter_test/flutter_test.dart';
// import 'package:flutter_mindful_minutes/flutter_mindful_minutes.dart';
// import 'package:flutter_mindful_minutes/flutter_mindful_minutes_platform_interface.dart';
// import 'package:flutter_mindful_minutes/flutter_mindful_minutes_method_channel.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';
//
// class MockFlutterMindfulMinutesPlatform
//     with MockPlatformInterfaceMixin
//     implements FlutterMindfulMinutesPlatform {
//
//   @override
//   Future<String?> getPlatformVersion() => Future.value('42');
// }
//
// void main() {
//   final FlutterMindfulMinutesPlatform initialPlatform = FlutterMindfulMinutesPlatform.instance;
//
//   test('$MethodChannelFlutterMindfulMinutes is the default instance', () {
//     expect(initialPlatform, isInstanceOf<MethodChannelFlutterMindfulMinutes>());
//   });
//
//   test('getPlatformVersion', () async {
//     FlutterMindfulMinutes flutterMindfulMinutesPlugin = FlutterMindfulMinutes();
//     MockFlutterMindfulMinutesPlatform fakePlatform = MockFlutterMindfulMinutesPlatform();
//     FlutterMindfulMinutesPlatform.instance = fakePlatform;
//
//     expect(await flutterMindfulMinutesPlugin.getPlatformVersion(), '42');
//   });
// }
