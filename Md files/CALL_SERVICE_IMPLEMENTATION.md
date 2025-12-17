# Call Service Implementation Guide

## 1. Service Overview and Purpose

The Call Service is a comprehensive voice and video calling solution integrated into the existing Flutter chat application. It enables real-time communication between users with features including:

- **Voice Calling**: High-quality audio calls with noise cancellation
- **Video Calling**: HD video streaming with camera switching capabilities
- **Call Management**: Incoming/outgoing call handling, call states, and UI
- **Push Notifications**: Background call notifications for incoming calls
- **Call History**: Persistent storage of call logs and durations

### Architecture Overview
```
Frontend (Flutter) ↔ Call Service ↔ Signaling Server ↔ WebRTC ↔ Firebase
```

## 2. Required Dependencies

### Core Dependencies (Add to pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # WebRTC for audio/video calls
  flutter_webrtc: ^0.9.30
  
  # Signaling and connection management
  socket_io_client: ^2.0.3
  
  # Push notifications for calls
  firebase_messaging: ^14.7.6
  
  # Permissions handling
  permission_handler: ^11.0.1
  
  # Audio management
  just_audio: ^0.9.35
  audioplayers: ^5.0.1
  
  # Device info for call logs
  device_info_plus: ^9.0.3
  
  # Local notifications
  flutter_local_notifications: ^16.3.0

dev_dependencies:
  # Mocking for testing
  mockito: ^5.4.2
  build_runner: ^2.4.6
```

### Firebase Configuration

1. Enable Firebase Cloud Messaging in Firebase Console
2. Add FCM configuration to `android/app/google-services.json`
3. Configure iOS push notifications if targeting iOS

## 3. Step-by-Step Implementation Guide

### Step 1: Project Structure Setup

Create the following directory structure:
```
lib/
  services/
    call/
      call_service.dart          # Main call service
      signaling_service.dart     # Socket.io signaling
      webrtc_manager.dart        # WebRTC configuration
      call_repository.dart       # Firestore operations
  
  components/
    call/
      call_screen.dart          # Main call UI
      incoming_call_dialog.dart # Incoming call UI
      call_buttons.dart         # Call control buttons
  
  model/
    call_model.dart             # Call data models
```

### Step 2: Core Call Service Implementation

#### lib/services/call/call_service.dart
```dart
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';
import 'webrtc_manager.dart';
import 'call_repository.dart';

class CallService {
  final SignalingService _signalingService;
  final WebRTCManager _webRTCManager;
  final CallRepository _callRepository;
  
  CallService()
      : _signalingService = SignalingService(),
        _webRTCManager = WebRTCManager(),
        _callRepository = CallRepository();
  
  // Initialize call service
  Future<void> initialize() async {
    await _signalingService.connect();
    await _webRTCManager.initialize();
    _setupSignalingListeners();
  }
  
  // Make a call to another user
  Future<void> makeCall(String targetUserId, bool isVideoCall) async {
    final callId = _generateCallId();
    
    // Create local offer
    final offer = await _webRTCManager.createOffer(isVideoCall);
    
    // Send call invitation via signaling
    await _signalingService.sendCallInvitation(
      targetUserId,
      callId,
      offer,
      isVideoCall,
    );
    
    // Create call record in Firestore
    await _callRepository.createCallRecord(
      callId,
      targetUserId,
      isVideoCall,
      CallStatus.ringing,
    );
  }
  
  // Answer incoming call
  Future<void> answerCall(String callId, RTCSessionDescription offer) async {
    // Create answer
    final answer = await _webRTCManager.createAnswer(offer);
    
    // Send answer via signaling
    await _signalingService.sendAnswer(callId, answer);
    
    // Update call status
    await _callRepository.updateCallStatus(callId, CallStatus.ongoing);
  }
  
  // End current call
  Future<void> endCall(String callId) async {
    await _signalingService.sendCallEnd(callId);
    await _webRTCManager.close();
    await _callRepository.updateCallStatus(callId, CallStatus.ended);
  }
  
  // Private methods
  String _generateCallId() => DateTime.now().millisecondsSinceEpoch.toString();
  
  void _setupSignalingListeners() {
    _signalingService.onCallInvitation = (callId, offer, isVideoCall) {
      // Handle incoming call
    };
    
    _signalingService.onAnswer = (answer) {
      _webRTCManager.setRemoteDescription(answer);
    };
    
    _signalingService.onIceCandidate = (candidate) {
      _webRTCManager.addIceCandidate(candidate);
    };
  }
}
```

### Step 3: Signaling Service Implementation

#### lib/services/call/signaling_service.dart
```dart
import 'package:socket_io_client/socket_io_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  Socket? _socket;
  
  Future<void> connect() async {
    _socket = io('https://your-signaling-server.com', {
      'transports': ['websocket'],
      'autoConnect': true,
    });
    
    _socket!.onConnect((_) => print('Connected to signaling server'));
    _socket!.onDisconnect((_) => print('Disconnected from signaling server'));
    
    // Setup event listeners
    _setupEventListeners();
  }
  
  Future<void> sendCallInvitation(
    String targetUserId,
    String callId,
    RTCSessionDescription offer,
    bool isVideoCall,
  ) async {
    _socket!.emit('call-invitation', {
      'targetUserId': targetUserId,
      'callId': callId,
      'offer': offer.toMap(),
      'isVideoCall': isVideoCall,
    });
  }
  
  // Other signaling methods...
}
```

### Step 4: WebRTC Manager Implementation

#### lib/services/call/webrtc_manager.dart
```dart
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCManager {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  Future<void> initialize() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        // Add your TURN servers here
      ]
    };
    
    _peerConnection = await createPeerConnection(configuration);
    
    // Setup event listeners
    _peerConnection!.onIceCandidate = (candidate) {
      // Send ICE candidate to remote peer
    };
    
    _peerConnection!.onTrack = (stream) {
      // Handle remote stream
    };
  }
  
  Future<MediaStream> getLocalStream(bool isVideoCall) async {
    final mediaConstraints = {
      'audio': true,
      'video': isVideoCall ? {
        'mandatory': {
          'minWidth': '1280',
          'minHeight': '720',
          'minFrameRate': '30',
        }
      } : false
    };
    
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    return _localStream!;
  }
  
  // Other WebRTC methods...
}
```

### Step 5: Call UI Components

#### lib/components/call/call_screen.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallScreen extends StatefulWidget {
  final bool isVideoCall;
  final String callId;
  final String otherUserId;
  
  const CallScreen({
    required this.isVideoCall,
    required this.callId,
    required this.otherUserId,
  });
  
  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _setupCall();
  }
  
  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }
  
  void _setupCall() {
    // Setup local and remote streams
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Remote video
          if (widget.isVideoCall)
            RTCVideoView(_remoteRenderer),
          
          // Local video preview
          if (widget.isVideoCall)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                width: 100,
                height: 150,
                child: RTCVideoView(_localRenderer),
              ),
            ),
          
          // Call controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute button
                // Video toggle
                // End call button
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## 4. Configuration Options and Parameters

### WebRTC Configuration
```dart
const rtcConfiguration = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {
      'urls': 'turn:your-turn-server.com:3478',
      'username': 'your-username',
      'credential': 'your-credential'
    }
  ],
  'iceTransportPolicy': 'all',
  'bundlePolicy': 'max-bundle',
  'rtcpMuxPolicy': 'require',
};
```

### Media Constraints
```dart
const audioConstraints = {
  'echoCancellation': true,
  'noiseSuppression': true,
  'autoGainControl': true,
};

const videoConstraints = {
  'width': {'ideal': 1280},
  'height': {'ideal': 720},
  'frameRate': {'ideal': 30},
};
```

### Firebase Call Document Structure
```dart
{
  'callId': 'unique-call-id',
  'callerId': 'user-id-1',
  'receiverId': 'user-id-2',
  'startTime': Timestamp.now(),
  'endTime': null,
  'duration': 0,
  'status': 'ringing', // ringing, ongoing, ended, missed
  'type': 'video', // audio, video
  'participants': ['user-id-1', 'user-id-2'],
}
```

## 5. Testing Procedures

### Unit Tests
```dart
group('CallService Tests', () {
  late CallService callService;
  late MockSignalingService mockSignaling;
  
  setUp(() {
    mockSignaling = MockSignalingService();
    callService = CallService();
  });
  
  test('should initialize successfully', () async {
    when(mockSignaling.connect()).thenAnswer((_) async => true);
    
    await callService.initialize();
    
    expect(callService.isInitialized, true);
  });
  
  test('should handle call invitation', () async {
    // Test call invitation flow
  });
});
```

### Integration Tests
```dart
group('Call Integration Tests', () {
  testWidgets('should display call screen for video call', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CallScreen(
          isVideoCall: true,
          callId: 'test-call-123',
          otherUserId: 'test-user-456',
        ),
      ),
    );
    
    expect(find.byType(RTCVideoView), findsNWidgets(2));
    expect(find.text('End Call'), findsOneWidget);
  });
});
```

### Manual Testing Checklist
- [ ] Audio call initiation and reception
- [ ] Video call initiation and reception  
- [ ] Call acceptance and rejection
- [ ] Microphone mute/unmute functionality
- [ ] Camera on/off functionality
- [ ] Speakerphone toggle
- [ ] Call duration tracking
- [ ] Call history recording
- [ ] Push notifications for incoming calls
- [ ] Background call handling
- [ ] Network resilience testing

## 6. Deployment Considerations

### Server Requirements
- **Signaling Server**: Node.js server with Socket.IO
- **TURN Server**: Coturn or similar for NAT traversal
- **Firebase**: For user authentication and call history

### Performance Optimization
- Implement bandwidth adaptation
- Add echo cancellation and noise suppression
- Optimize video codec selection (VP8/VP9/H264)
- Implement adaptive bitrate streaming

### Security Considerations
- Use HTTPS/WSS for all communications
- Implement DTLS-SRTP for media encryption
- Validate user permissions for calls
- Secure TURN server credentials
- Implement call rate limiting

### Monitoring and Analytics
- Track call success/failure rates
- Monitor audio/video quality metrics
- Log call durations and participant counts
- Track user engagement with call features

### Platform-Specific Considerations

#### Android
- Add microphone and camera permissions
- Configure foreground service for ongoing calls
- Handle audio focus management
- Implement wake lock for call duration

#### iOS
- Configure background modes for VoIP
- Add microphone and camera usage descriptions
- Implement CallKit integration
- Handle audio session management

## Next Steps

1. **Review and approve** this implementation plan
2. **Set up signaling server** infrastructure
3. **Configure TURN servers** for NAT traversal
4. **Implement core components** following this guide
5. **Test thoroughly** on both Android and iOS
6. **Deploy to production** with monitoring in place

This comprehensive implementation will provide a robust, scalable calling solution integrated seamlessly with your existing chat application.