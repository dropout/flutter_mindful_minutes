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

  void onCheckIfAvailable(BuildContext context) async {
    debugPrint('Checking if API is available...');
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final isAvailable = await _flutterMindfulMinutesPlugin.isAvailable();
    if (!mounted) return;
    setState(() {
      _isApiAvailable = isAvailable;
    });
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('API available: $isAvailable'),
      ),
    );
  }

  void onGetStatusForRequest(BuildContext context) async {
    debugPrint('Checking request status...');
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final requestStatus = await _flutterMindfulMinutesPlugin
        .getRequestForAuthorizationStatus();
    if (!mounted) return;
    setState(() {
      _requestStatus = requestStatus;
    });
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Request status: $requestStatus'),
      ),
    );
  }

  void onGetAuthorizationStatus(BuildContext context) async {
    debugPrint('Checking authorization status...');
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authorizationStatus = await _flutterMindfulMinutesPlugin
        .getAuthorizationStatus();
    if (!mounted) return;
    setState(() {
      _authorizationStatus = authorizationStatus;
    });
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Authorization status: $authorizationStatus'),
      ),
    );
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("STATUS", style: Theme.of(ctx).textTheme.titleMedium),
                  Divider(),
                  buildRow(
                    'Health API available:', 
                    Text(_isApiAvailable ? 'Yes' : 'No',  
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                        fontWeight: .bold,
                        color: _isApiAvailable ? Colors.green : Colors.red,
                      )
                    )
                  ),
                  buildRow(
                    'Request status:', 
                    Text(_requestStatus.name,
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                        fontWeight: .bold,
                        color: _requestStatus == .shouldRequest ? Colors.green : Colors.red,
                      )
                    )
                  ),
                  buildRow(
                    'Authorization status:', 
                    Text(_authorizationStatus.name,
                      style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                          fontWeight: .bold,
                          color: _authorizationStatus == .authorized ? Colors.green : Colors.red,
                        )
                    )
                  ),                  
                  SizedBox(height: 32),
                  Text("ACTIONS", style: Theme.of(ctx).textTheme.titleMedium),
                  Divider(),
                  OutlinedButton(
                    onPressed: () => onCheckIfAvailable(ctx),
                    child: Text(
                      'Check availability', 
                      textAlign: .center,                     
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => onGetStatusForRequest(ctx),
                    child: const Text('Check request status', textAlign: .center),
                  ),
                  OutlinedButton(
                    onPressed: () => onGetAuthorizationStatus(ctx),
                    child: const Text('Check authorization status', textAlign: .center),
                  ),
                  OutlinedButton(
                    onPressed: () => onRequestAuthorization(ctx),
                    child: const Text('Launch request System UI', textAlign: .center),
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
