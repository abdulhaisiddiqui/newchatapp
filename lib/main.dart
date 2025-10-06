import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:chatapp/firebase_options.dart';
import 'package:chatapp/pages/bottomNav_screen.dart';
import 'package:chatapp/pages/chat_page.dart';
import 'package:chatapp/pages/chat_page_chatview.dart';
import 'package:chatapp/pages/splash_screen.dart';
import 'package:chatapp/services/auth/auth_gate.dart';
import 'package:chatapp/services/auth/auth_service.dart';
import 'package:chatapp/services/call/call_manager.dart';
import 'package:chatapp/services/secure_storage_service.dart';
import 'package:chatapp/services/user/user_status_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://45d6ea8ba3eeadf9b5edd43d4d296f7a@o4510137199951872.ingest.de.sentry.io/4510137202638928';
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
    },
    appRunner: () async {
      // Ensure Flutter binding is initialized in the same zone as runApp
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // ✅ CRITICAL: Initialize call manager to start listening for incoming calls
      await CallManager.instance.initialize();

      // Background handler register
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

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

            if (chatRoomId != null &&
                receiverId != null &&
                receiverEmail != null) {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => ChatPageChatView(
                    receiverUserId: receiverId,
                    receiverUserEmail: receiverEmail,
                  ),
                ),
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
      final DarwinInitializationSettings iosInit =
          DarwinInitializationSettings();
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

      // TODO: Remove this line after sending the first sample event to sentry.
      await Sentry.captureException(Exception('This is a sample exception.'));

      runApp(
        SentryWidget(
          child: ChangeNotifierProvider(
            create: (context) => AuthService(),
            child: const MyApp(),
          ),
        ),
      );
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _token;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotificationsAndPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Set user offline when app is disposed
    UserStatusService().setUserOffline();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and responding to user input
        UserStatusService().setUserOnline();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is not visible or not responding
        UserStatusService().setUserOffline();
        break;
    }
  }

  Future<void> _initNotificationsAndPermissions() async {
    // ------------- WEB -------------
    if (kIsWeb) {
      // On web we must ensure service-worker exists (web/firebase-messaging-sw.js)
      // and request permission using the firebase_messaging API.
      try {
        NotificationSettings settings = await FirebaseMessaging.instance
            .requestPermission(alert: true, badge: true, sound: true);
        print('Web notification permission: ${settings.authorizationStatus}');

        // Get a token for web (supply your VAPID key)
        // TODO: Replace with your actual VAPID key from Firebase Console → Project Settings → Cloud Messaging → Web Push certificates
        final token = await FirebaseMessaging.instance.getToken(
          vapidKey:
              null, // Set to null to avoid the error until you add your VAPID key
        );
        print('FCM web token: $token');
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
      } catch (e, st) {
        print('Web messaging init error: $e\n$st');
      }
      return;
    }

    // ------------- MOBILE (Android / iOS) -------------
    // Only execute Platform.* when not on web
    try {
      if (Platform.isIOS) {
        // iOS permission
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } else {
        try {
          if (Platform.isAndroid) {
            // For Android 13+, you may need POST_NOTIFICATIONS permission; handle with permission_handler if needed.
            // Many Android devices don't require explicit runtime permission pre Android 13.
          }
        } catch (e) {
          // Platform not available
        }
      }
    } catch (e) {
      print('Mobile permission error: $e');
    }

    // Get token and save for mobile
    String? token = await FirebaseMessaging.instance.getToken();
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

    // Setup listeners for mobile
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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const SplashScreen(),
      routes: {
        '/auth': (context) => const AuthGate(),
        '/home': (context) => const BottomNavScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, String>?;
          if (args != null) {
            // Handle both argument formats
            final userId = args['receiverUserId'] ?? args['userId'] ?? '';
            final userEmail =
                args['receiverUserEmail'] ?? args['username'] ?? '';
            return MaterialPageRoute(
              builder: (context) => ChatPageChatView(
                receiverUserId: userId,
                receiverUserEmail: userEmail,
              ),
            );
          }
        }
        return null;
      },
    );
  }
}
