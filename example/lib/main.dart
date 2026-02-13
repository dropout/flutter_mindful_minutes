import 'package:flutter/material.dart';
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
  bool _hasPermissions = false;
  bool _isAvailable = false;
  final _flutterMindfulMinutesPlugin = FlutterMindfulMinutes();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    final results = await Future.wait<bool>([
      _flutterMindfulMinutesPlugin.isAvailable().catchError((_) => false),
      _flutterMindfulMinutesPlugin.hasPermission().catchError((_) => false),
    ]);
    if (!mounted) return;
    final isAvailable = results[0];
    final hasAccess = results[1];
    setState(() {
      _initialized = true;
      _hasPermissions = hasAccess;
      _isAvailable = isAvailable;
    });
  }

  void onRequestPermission() async {
    final hasAccess = await _flutterMindfulMinutesPlugin.requestPermission();
    setState(() {
      _hasPermissions = hasAccess;
    });
  }

  void onWriteMindfulMinutes(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 30));
    final endTime = now;
    try {
      await _flutterMindfulMinutesPlugin.writeMindfulMinutes(startTime, endTime);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Successfully wrote mindful minutes')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Failed to write mindful minutes')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        // Push down builder results in the widget tree to make
        // ScaffoldMessenger available in the onWriteMindfulMinutes function.
        body: Builder(
          builder: (ctx) {
            if (!_initialized) {
              return const CircularProgressIndicator();
            }
            return Column(
              children: [
                ListTile(
                  title: const Text('Is mindful minutes API available?'),
                  trailing: Icon(
                    _isAvailable ? Icons.check : Icons.close,
                    color: _isAvailable ? Colors.green : Colors.red,
                  ),
                ),
                ListTile(
                  title: const Text('Has permission to write mindful minutes?'),
                  trailing: Icon(
                    _hasPermissions ? Icons.check : Icons.close,
                    color: _hasPermissions ? Colors.green : Colors.red,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onRequestPermission,
                        child: const Text('Request access'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => onWriteMindfulMinutes(ctx),
                        child: const Text('Write mindful minutes'),
                      ),
                    )
                  ],
                ),
              ]
            );
          },
        ),
      ),
    );
  }
}
