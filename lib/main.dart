import 'dart:io';
import 'package:chatapp/firebase_options.dart';
import 'package:chatapp/services/auth/auth_gate.dart';
import 'package:chatapp/services/auth/auth_service.dart';
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

  // Background handler register
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Init local notifications
  const AndroidInitializationSettings androidInit =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings iosInit = DarwinInitializationSettings();
  final InitializationSettings initSettings =
  InitializationSettings(android: androidInit, iOS: iosInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (payload) {
      // handle tap
    },
  );

  // Create Android channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
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
      final uid = "REPLACE_WITH_CURRENT_USER_ID"; // Auth ke baad yaha user.uid lagana
      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token])
      }, SetOptions(merge: true));
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('Token refreshed: $newToken');
      final uid = "REPLACE_WITH_CURRENT_USER_ID";
      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([newToken])
      }, SetOptions(merge: true));
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
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}
