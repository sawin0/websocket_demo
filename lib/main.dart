import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:web_socket_channel/io.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  IOWebSocketChannel? _channel;
  Timer? _reconnectTimer;
  final String _token = 'your_token_here'; // Replace with your actual token
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _connect();
  }

  void _connect() {
    _channel = IOWebSocketChannel.connect(
      Uri.parse(
        'websocket_url_here', // Replace with your actual WebSocket URL
      ),
      headers: {'Authorization': 'Bearer $_token'},
    );
    _channel!.stream.listen(
      (msg) {
        print('WS message: $msg');
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // If you need periodic pings:
    _channel?.sink.add('ping');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
  }
}

void main() {
  // Enables communication between UI and service:
  FlutterForegroundTask.initCommunicationPort();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Configure notification & service behavior:
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'socket_service',
        channelName: 'WebSocket Service',
        channelDescription: 'Maintains WS connection',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000),
        allowWakeLock: true,
      ),
    );
    return MaterialApp(home: WithForegroundTask(child: SocketHomePage()));
  }
}

class SocketHomePage extends StatefulWidget {
  const SocketHomePage({super.key});

  @override
  State<SocketHomePage> createState() => _SocketHomePageState();
}

class _SocketHomePageState extends State<SocketHomePage> {
  String _status = 'Stopped';

  Future<void> _startService() async {
    final result = await FlutterForegroundTask.startService(
      serviceId: 999,
      notificationTitle: 'WebSocket Service',
      notificationText: 'Running…',
      callback: startCallback,
    );
    if (result is ServiceRequestSuccess) {
      setState(() => _status = 'Running');
    } else {
      setState(() => _status = 'Failed to start (${result.runtimeType})');
    }
  }

  Future<void> _stopService() async {
    final result = await FlutterForegroundTask.stopService();
    if (result is ServiceRequestSuccess) {
      setState(() => _status = 'Stopped');
    } else {
      setState(() => _status = 'Failed to stop (${result.runtimeType})');
    }
  }

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.isRunningService.then(
      (isRunning) =>
          setState(() => _status = isRunning ? 'Running' : 'Stopped'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Persistent WebSocket')),
      body: Center(child: Text('Status: $_status')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'start',
            onPressed: _startService,
            tooltip: 'Start',
            child: const Icon(Icons.play_arrow),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'stop',
            onPressed: _stopService,
            tooltip: 'Stop',
            child: const Icon(Icons.stop),
          ),
        ],
      ),
    );
  }
}
