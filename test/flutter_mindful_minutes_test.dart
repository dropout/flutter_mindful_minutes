import 'package:flutter/services.dart';
import 'package:flutter_mindful_minutes/flutter_mindful_minutes.dart';
import 'package:flutter_mindful_minutes/flutter_mindful_minutes.g.dart';
import 'package:flutter_test/flutter_test.dart';

/// Host API that fails every call with the given [PlatformException].
class _FailingHostApi extends FlutterMindfulMinutesHostApi {
  _FailingHostApi(this.error);

  final PlatformException error;

  @override
  Future<void> checkAvailability() => Future.error(error);

  @override
  Future<AuthorizationStatus> getAuthorizationStatus() => Future.error(error);

  @override
  Future<RequestStatusForAuthorization> getRequestForAuthorizationStatus() =>
      Future.error(error);

  @override
  Future<bool> requestAuthorization() => Future.error(error);

  @override
  Future<bool> writeMindfulMinutes(int startSeconds, int endSeconds) =>
      Future.error(error);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FlutterMindfulMinutes pluginFailingWith(String code) =>
      FlutterMindfulMinutes.withApi(_FailingHostApi(
        PlatformException(code: code, message: 'msg', details: {'k': 'v'}),
      ));

  final expectedTypes = <String, TypeMatcher<FlutterMindfulMinutesException>>{
    'health_data_unavailable': isA<HealthDataUnavailableException>(),
    'provider_update_required': isA<ProviderUpdateRequiredException>(),
    'mindfulness_not_supported': isA<MindfulnessNotSupportedException>(),
    'activity_not_supported': isA<ActivityNotSupportedException>(),
    'missing_entitlement': isA<MissingEntitlementException>(),
    'missing_permission_declaration':
        isA<MissingPermissionDeclarationException>(),
  };

  final calls = <String, Future<Object?> Function(FlutterMindfulMinutes)>{
    'checkAvailability': (p) => p.checkAvailability(),
    'getAuthorizationStatus': (p) => p.getAuthorizationStatus(),
    'getRequestForAuthorizationStatus': (p) =>
        p.getRequestForAuthorizationStatus(),
    'requestAuthorization': (p) => p.requestAuthorization(),
    'writeMindfulMinutes': (p) =>
        p.writeMindfulMinutes(DateTime(2026), DateTime(2026, 1, 2)),
  };

  for (final MapEntry(key: method, value: call) in calls.entries) {
    group(method, () {
      for (final MapEntry(key: code, value: matcher) in expectedTypes.entries) {
        test('maps "$code" to its exception type', () async {
          await expectLater(
            call(pluginFailingWith(code)),
            throwsA(matcher
                .having((e) => e.message, 'message', 'msg')
                .having((e) => e.details, 'details', {'k': 'v'})),
          );
        });
      }

      test('maps unknown codes to UnknownMindfulMinutesException', () async {
        await expectLater(
          call(pluginFailingWith('something_else')),
          throwsA(isA<UnknownMindfulMinutesException>()
              .having((e) => e.code, 'code', 'something_else')),
        );
      });
    });
  }

  test('availability reasons share MindfulMinutesUnavailableException', () {
    for (final code in [
      'health_data_unavailable',
      'provider_update_required',
      'mindfulness_not_supported',
      'activity_not_supported',
    ]) {
      expect(
        pluginFailingWith(code).checkAvailability(),
        throwsA(isA<MindfulMinutesUnavailableException>()),
      );
    }
    expect(
      pluginFailingWith('missing_entitlement').checkAvailability(),
      throwsA(isNot(isA<MindfulMinutesUnavailableException>())),
    );
  });
}
