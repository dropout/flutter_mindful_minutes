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
  bool _hasAccess = false;
  bool _isAvailable = false;
  final _flutterMindfulMinutesPlugin = FlutterMindfulMinutes();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    bool isAvailable = false;
    try {
      isAvailable = await _flutterMindfulMinutesPlugin.isAvailable();
    } catch (e) {
      isAvailable = false;
    }

    if (!mounted) return;
    setState(() {
      _initialized = true;
      _isAvailable = isAvailable;
    });
  }

  void onRequestPermission() async {
    final hasAccess = await _flutterMindfulMinutesPlugin.requestPermission();
    setState(() {
      _hasAccess = hasAccess;
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
        body: Column(
          children: [
            Text('Has access to mindful minutes: $_hasAccess\n'),
            TextButton(
              onPressed: onRequestPermission,
              child: const Text('Request access'),
            ),
            TextButton(
              onPressed: () => onWriteMindfulMinutes(context),
              child: const Text('Write mindful minutes'),
            ),
          ]
        ),
      ),
    );
  }
}
