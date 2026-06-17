import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:flutter_mindful_minutes/flutter_mindful_minutes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  bool _isApiAvailable = false;
  AuthorizationStatus _authorizationStatus = .unknown;
  RequestStatusForAuthorization _requestStatus = .unknown;

  final _flutterMindfulMinutesPlugin = FlutterMindfulMinutes();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      final isAvailable = await _flutterMindfulMinutesPlugin.isAvailable();
      final authorizationStatus = await _flutterMindfulMinutesPlugin
          .getAuthorizationStatus();
      final requestStatus = await _flutterMindfulMinutesPlugin
          .getRequestForAuthorizationStatus();

      if (!mounted) return;

      setState(() {
        _initialized = true;
        _isApiAvailable = isAvailable;
        _authorizationStatus = authorizationStatus;
        _requestStatus = requestStatus;
      });
    } catch (e) {
      debugPrint('Error initializing platform state: $e');
    }
  }

  void onRequestAuthorization(BuildContext context) async {
    debugPrint('Requesting permission...');
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final requestSheetShown = await _flutterMindfulMinutesPlugin
        .requestAuthorization();

    if (!requestSheetShown) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Permission request was not shown.')),
      );
      return;
    }

    final authorizationStatus = await _flutterMindfulMinutesPlugin
        .getAuthorizationStatus();

    if (!mounted) return;

    setState(() {
      _authorizationStatus = authorizationStatus;
    });

    if (authorizationStatus != AuthorizationStatus.authorized) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Permission denied. Status: $authorizationStatus'),
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Permission granted.')),
      );
    }
  }

  void onWriteMindfulMinutes(BuildContext context) async {
    debugPrint('Writing mindful minutes...');
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 30));
    final endTime = now;
    try {
      await _flutterMindfulMinutesPlugin.writeMindfulMinutes(
        startTime,
        endTime,
      );
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Successfully wrote mindful minutes')),
      );
    } on PlatformException catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to write mindful minutes from. Error: ${e.message} Code: ${e.code}',
          ),
        ),
      );
      debugPrint('PlatformException occured writing mindful minutes: $e');
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Unknown error writing mindful minutes.',
          ),
        ),
      );
      debugPrint('Unknown error writing mindful minutes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Mindful Minutes Example')),
        // Push down builder results in the widget tree to make
        // ScaffoldMessenger available in the onWriteMindfulMinutes function.
        body: Builder(
          builder: (ctx) {
            if (!_initialized) {
              return const CircularProgressIndicator();
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  buildRow('Health API available:', Text(_isApiAvailable ? 'Yes' : 'No')),                  
                  buildRow('Request status:', Text(_requestStatus.name)),
                  buildRow('Authorization status:', Text(_authorizationStatus.name)),                  
                  SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: () => onRequestAuthorization(ctx),
                    child: const Text('Request access', textAlign: .center),
                  ),
                  OutlinedButton(
                    onPressed: () => onWriteMindfulMinutes(ctx),
                    child: const Text(
                      'Write mindful minutes',
                      textAlign: .center,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildRow(String label, Widget value) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Text(label),
          Spacer(),
          value,
        ],
      ),
    );
  }
}
