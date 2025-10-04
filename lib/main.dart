import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:chatapp/firebase_options.dart';
import 'package:chatapp/pages/bottomNav_screen.dart';
import 'package:chatapp/pages/chat_page.dart';
import 'package:chatapp/pages/splash_screen.dart';
import 'package:chatapp/services/auth/auth_gate.dart';
import 'package:chatapp/services/auth/auth_service.dart';
import 'package:chatapp/services/call/call_manager.dart';
import 'package:chatapp/services/secure_storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

// 1) Background handler (top-level)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

// 2) Local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 3) Global navigator key for notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Android channel (for Android 8+)
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for chat message notifications.',
  importance: Importance.high,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ CRITICAL: Initialize call manager to start listening for incoming calls
  await CallManager.instance.initialize();

  // Background handler register
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔔 Initialize Awesome Notifications
  await AwesomeNotifications().initialize(
    null, // icon asset name for Android, or null for default app icon
    [
      NotificationChannel(
        channelKey: 'chat_messages',
        channelName: 'Chat Messages',
        channelDescription: 'Notifications for new chat messages',
        defaultColor: const Color(0xFF1976D2),
        importance: NotificationImportance.High,
        channelShowBadge: true,
        playSound: true,
        enableVibration: true,
      ),
      NotificationChannel(
        channelKey: 'stories',
        channelName: 'Story Updates',
        channelDescription: 'Alerts for story uploads and updates',
        defaultColor: const Color(0xFF00BCD4),
        importance: NotificationImportance.Default,
        channelShowBadge: true,
        playSound: true,
        enableVibration: true,
      ),
      NotificationChannel(
        channelKey: 'calls',
        channelName: 'Call Notifications',
        channelDescription: 'Incoming call alerts',
        defaultColor: const Color(0xFF4CAF50),
        importance: NotificationImportance.Max,
        channelShowBadge: false,
        playSound: true,
        enableVibration: true,
        criticalAlerts: true,
      ),
    ],
  );

  // 🔹 Ask user permission (for iOS & Android 13+)
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  // 🚀 Set up notification listeners
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: (ReceivedAction receivedAction) async {
      final payload = receivedAction.payload ?? {};

      // Handle reply from notification
      if (receivedAction.buttonKeyPressed == 'REPLY' &&
          receivedAction.buttonKeyInput.isNotEmpty) {
        final chatRoomId = payload['chatRoomId'];
        final message = receivedAction.buttonKeyInput;

        if (chatRoomId != null) {
          // Send reply message to Firestore
          // This would need to be implemented in your chat service
          print('Reply from notification: $message to chat $chatRoomId');
        }
      }
      // Handle normal notification tap
      else if (receivedAction.channelKey == 'chat_messages') {
        final chatRoomId = payload['chatRoomId'];
        final receiverId = payload['receiverId'];
        final receiverEmail = payload['receiverEmail'];

        if (chatRoomId != null && receiverId != null && receiverEmail != null) {
          navigatorKey.currentState?.pushNamed(
            '/chat',
            arguments: {
              'receiverUserId': receiverId,
              'receiverUserEmail': receiverEmail,
            },
          );
        }
      } else if (receivedAction.channelKey == 'stories') {
        navigatorKey.currentState?.pushNamed('/home');
      } else if (receivedAction.channelKey == 'calls') {
        final callerId = payload['callerId'];
        if (callerId != null) {
          // Handle call notifications
          print('Incoming call from: $callerId');
        }
      }
    },
  );

  // Init local notifications (keeping for Firebase messaging compatibility)
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings iosInit = DarwinInitializationSettings();
  final InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (payload) {
      // handle tap
    },
  );

  // Create Android channel (keeping for Firebase messaging compatibility)
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _token;

  @override
  void initState() {
    super.initState();
    requestPermissions();
    getTokenAndSave();
    setupListeners();
  }

  void requestPermissions() async {
    if (Platform.isIOS) {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('iOS permission: ${settings.authorizationStatus}');
    }
  }

  void getTokenAndSave() async {
    String? token = await _messaging.getToken();
    print('FCM token: $token');
    _token = token;
    if (token != null) {
      final uid = await SecureStorageService().getUserId();
      if (uid != null) {
        await _firestore.collection('users').doc(uid).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
        }, SetOptions(merge: true));

        // Save FCM token to secure storage
        await SecureStorageService().saveFCMToken(token);
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('Token refreshed: $newToken');
      final uid = await SecureStorageService().getUserId();
      if (uid != null) {
        await _firestore.collection('users').doc(uid).set({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
        }, SetOptions(merge: true));

        // Update FCM token in secure storage
        await SecureStorageService().saveFCMToken(newToken);
      }
    });
  }

  void setupListeners() {
    // Foreground message
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('onMessage: ${message.notification?.title}');
      RemoteNotification? n = message.notification;

      if (n != null) {
        flutterLocalNotificationsPlugin.show(
          n.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: message.data['messageId'] ?? '',
        );
      }
    });

    // Notification tap (background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('onMessageOpenedApp: ${message.data}');
    });

    // Terminated state open
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('getInitialMessage: ${message.data}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add navigator key for notifications
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1976D2),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF1976D2), width: 2),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthGate(),
        '/home': (context) => const BottomNavScreen(),
        '/chat': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          if (args != null) {
            return ChatPage(
              receiverUserId: args['receiverUserId'] as String,
              receiverUserEmail: args['receiverUserEmail'] as String,
            );
          }
          return const BottomNavScreen(); // Fallback
        },
      },
    );
  }
}
