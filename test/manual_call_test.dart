import 'package:flutter/material.dart';
import 'package:chatapp/services/call/call_manager.dart';
import 'package:chatapp/pages/call_screen.dart';

void main() {
  runApp(const CallTestApp());
}

class CallTestApp extends StatelessWidget {
  const CallTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const CallTestScreen(),
    );
  }
}

class CallTestScreen extends StatefulWidget {
  const CallTestScreen({Key? key}) : super(key: key);

  @override
  _CallTestScreenState createState() => _CallTestScreenState();
}

class _CallTestScreenState extends State<CallTestScreen> {
  final CallManagerInterface _callManager = CallManager.instance;
  bool _isInitialized = false;
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeCallManager();
  }

  Future<void> _initializeCallManager() async {
    try {
      // Check if already initialized to avoid duplicate initialization
      if (!_callManager.isInitialized) {
        await _callManager.initialize();
      }
      setState(() {
        _isInitialized = true;
        _statusMessage = 'Call manager initialized successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing call manager: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call Functionality Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isInitialized
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CallScreen(),
                        ),
                      );
                    }
                  : null,
              child: const Text('Open Call Screen'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isInitialized
                  ? () async {
                      final result = await _callManager.startAudioCall(
                        'test_user_id',
                        'Test User',
                      );
                      setState(() {
                        _statusMessage = result
                            ? 'Audio call started successfully'
                            : 'Failed to start audio call';
                      });
                    }
                  : null,
              child: const Text('Test Audio Call'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isInitialized
                  ? () async {
                      final result = await _callManager.startVideoCall(
                        'test_user_id',
                        'Test User',
                      );
                      setState(() {
                        _statusMessage = result
                            ? 'Video call started successfully'
                            : 'Failed to start video call';
                      });
                    }
                  : null,
              child: const Text('Test Video Call'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isInitialized && _callManager.isInCall
                  ? () async {
                      final result = await _callManager.endCall();
                      setState(() {
                        _statusMessage = result
                            ? 'Call ended successfully'
                            : 'Failed to end call';
                      });
                    }
                  : null,
              child: const Text('End Current Call'),
            ),
          ],
        ),
      ),
    );
  }
}
