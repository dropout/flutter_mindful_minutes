
import 'package:flutter_mindful_minutes/flutter_mindful_minutes.g.dart';


class FlutterMindfulMinutes {

  final _api = FlutterMindfulMinutesHostApi();

  Future<bool> requestMindfulMinutesAuthorization() async {
    return await _api.requestMindfulMinutesAuthorization();
  }

  Future<bool> writeMindfulMinutes(DateTime startTime, DateTime endTime) async {
    return await _api.writeMindfulMinutes(
      (startTime.millisecondsSinceEpoch / 1000).toInt(),
      (endTime.millisecondsSinceEpoch / 1000).toInt(),
    );
  }

}
