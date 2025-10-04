import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:chatapp/pages/call_screen.dart';
import 'package:chatapp/services/call/call_manager.dart';
import 'package:chatapp/services/call/call_models.dart';

// Simple mock implementation
class MockCallManager implements CallManagerInterface {
  bool get isInitialized => true;
  Future<void> initialize() async {}
  bool get isInCall => false;
  CallInfo? get currentCall => null;

  void registerCallStateListener(CallStateListener listener) {}
  void unregisterCallStateListener(CallStateListener listener) {}

  Future<bool> startAudioCall(String userId, String userName) async {
    return true;
  }

  Future<bool> startVideoCall(String userId, String userName) async {
    return true;
  }

  Future<bool> answerCall() async => true;
  Future<bool> endCall() async => true;
  Future<bool> declineCall() async => true;

  Future<List<CallHistoryEntry>> getCallHistory(String userId) async {
    return _sampleHistory;
  }

  void handleIncomingCall(
    String callId,
    String userId,
    String userName,
    bool isVideo,
  ) {}

  void dispose() {}

  // Track method calls for verification
  final List<String> methodCalls = [];
}

// Sample call history
final _sampleHistory = [
  CallHistoryEntry(
    callId: 'call1',
    userId: 'user1',
    userName: 'John Doe',
    timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    duration: const Duration(minutes: 5),
    isVideo: false,
    direction: CallDirection.outgoing,
    userAvatar: null,
  ),
  CallHistoryEntry(
    callId: 'call2',
    userId: 'user2',
    userName: 'Jane Smith',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    duration: const Duration(minutes: 3),
    isVideo: true,
    direction: CallDirection.incoming,
    userAvatar: null,
  ),
  CallHistoryEntry(
    callId: 'call3',
    userId: 'user3',
    userName: 'Mike Johnson',
    timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    duration: null,
    isVideo: false,
    direction: CallDirection.missed,
    userAvatar: null,
  ),
];

void main() {
  late MockCallManager mockCallManager;

  setUp(() {
    mockCallManager = MockCallManager();
    CallManager.setInstanceForTesting(mockCallManager);
  });

  testWidgets('CallScreen displays call history', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CallScreen()));
    await tester.pumpAndSettle();

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('Mike Johnson'), findsOneWidget);

    expect(find.byIcon(Icons.call_made), findsOneWidget); // outgoing
    expect(find.byIcon(Icons.call_received), findsOneWidget); // incoming
    expect(find.byIcon(Icons.call_missed), findsOneWidget); // missed
  });

  testWidgets('CallScreen initiates audio call on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CallScreen()));
    await tester.pumpAndSettle();

    final callButton = find.byIcon(Icons.call).first;
    await tester.tap(callButton);
    await tester.pumpAndSettle();
  });

  testWidgets('CallScreen initiates video call on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CallScreen()));
    await tester.pumpAndSettle();

    final videoCallButton = find.byIcon(Icons.videocam).first;
    await tester.tap(videoCallButton);
    await tester.pumpAndSettle();
  });
}
