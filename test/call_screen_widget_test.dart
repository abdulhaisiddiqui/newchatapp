import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:chatapp/pages/call_screen.dart';
import 'package:chatapp/services/call/call_manager.dart';
import 'package:chatapp/services/call/call_models.dart';

@GenerateMocks([CallManagerInterface])
import 'call_screen_widget_test.mocks.dart';

void main() {
  late MockCallManagerInterface mockCallManager;
  late List<CallHistoryEntry> sampleHistory;

  setUp(() {
    mockCallManager = MockCallManagerInterface();
    sampleHistory = [
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

    // Stub methods
    when(
      mockCallManager.getCallHistory(any<String>()),
    ).thenAnswer((_) => Future.value(sampleHistory));
    when(
      mockCallManager.startAudioCall(any<String>(), any<String>()),
    ).thenAnswer((_) => Future.value(true));
    when(
      mockCallManager.startVideoCall(any<String>(), any<String>()),
    ).thenAnswer((_) => Future.value(true));

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

    verify(
      mockCallManager.startAudioCall(any<String>(), any<String>()),
    ).called(1);
  });

  testWidgets('CallScreen initiates video call on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CallScreen()));
    await tester.pumpAndSettle();

    final videoCallButton = find.byIcon(Icons.videocam).first;
    await tester.tap(videoCallButton);
    await tester.pumpAndSettle();

    verify(
      mockCallManager.startVideoCall(any<String>(), any<String>()),
    ).called(1);
  });
}
