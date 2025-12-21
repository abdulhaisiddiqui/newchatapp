# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository overview

This is a production-style Flutter chat application (`chatapp`) that uses Firebase for authentication, real-time messaging, file sharing, presence, notifications, and call metadata.

Core technologies:
- Flutter (Dart) mobile/web app
- Firebase: Auth, Firestore, Storage, Realtime Database (limited), Cloud Messaging
- Local & push notifications via `awesome_notifications` and `flutter_local_notifications`
- Error tracking with `sentry_flutter`
- UI chat layer using the `chatview` package (new chat screen)

Primary entry points and domains:
- `lib/main.dart` – app bootstrap, Firebase/Sentry init, notification channels, FCM handling, call manager initialization, and route configuration.
- `lib/pages/` – top-level screens (auth, home, chat, calls, contacts, settings, stories, media viewers).
- `lib/services/` – business logic for auth, chat, calls, files, notifications, connectivity, secure storage, stories, and user presence.
- `lib/model/` – core chat domain models (messages, attachments, message types, custom messages).
- `lib/components/` – reusable UI widgets for chat (bubbles, message renderers, pickers, previews, status indicators, etc.).

Extensive additional documentation lives in the `Md files/` directory and is worth consulting for deep-dives:
- `DEVELOPMENT_SUMMARY.md` – project overview, Firestore rules, setup, and structure.
- `FILE_SHARING_IMPLEMENTATION.md`, `IMPLEMENTATION_STEPS.md`, `IMPLEMENTATION_SUMMARY.md` – file sharing architecture and implementation details.
- `CHAT_MESSAGING_FIX.md` – messaging flow, chat room IDs, unread counts, and reliability fixes.
- `CHATVIEW_MIGRATION_README.md` – migration plan to the `chatview` UI.
- `FIRESTORE_RULES.md` – canonical Firestore security rules used by the app.
- `PRODUCTION_DEPLOYMENT_GUIDE.md` – end-to-end deployment and build commands.

## Commands & workflows

All commands below should be run from the repo root unless noted. The project assumes Flutter SDK `3.8.1+` and a configured Firebase project.

### Dependency install & setup

- Install Dart/Flutter dependencies:
  - `flutter pub get`
- (Once per environment) Configure Firebase:
  - Ensure `lib/firebase_options.dart` exists and matches your Firebase project.
  - Apply Firestore rules from `Md files/FIRESTORE_RULES.md` (or `DEVELOPMENT_SUMMARY.md`) in the Firebase console.
  - Enable Auth, Firestore, Storage, and Messaging in Firebase.

### Running the app

- Run on a connected device/simulator (debug):
  - `flutter run`
- Clean and rebuild (useful after dependency or native config changes):
  - `flutter clean`
  - `flutter pub get`
  - `flutter run`

### Static analysis

- Run Flutter analyzer with the configured lints (`analysis_options.yaml`):
  - `flutter analyze`

### Tests

Unit/widget tests live under `test/` and integration tests under `integration_test/`.

- Run all tests:
  - `flutter test`
- Run a specific unit/service test file (example – file service):
  - `flutter test test/services/file_service_test.dart`
- Run a specific widget test file (example – file picker component):
  - `flutter test test/components/file_picker_test.dart`
- Run the file sharing integration tests:
  - `flutter test integration_test/file_sharing_test.dart`

> Note: Some integration tests assume proper Firebase configuration and may require valid `firebase_options.dart` and a reachable backend.

### Release builds (reference)

Production deployment commands are fully documented in `Md files/PRODUCTION_DEPLOYMENT_GUIDE.md`. Key Flutter build commands (Android/iOS/Web) referenced there:

- Android APK / App Bundle:
  - `flutter build apk --release`
  - `flutter build appbundle --release`
- iOS (run on macOS with Xcode set up):
  - `flutter build ios --release`
  - `flutter build ipa --release`
- Web:
  - `flutter build web --release`

### Firebase Cloud Functions (optional backend)

There is a minimal Cloud Functions project under `functions/` (Node 18 runtime, `firebase-admin` + `firebase-functions`). It has no npm scripts defined yet.

- Install dependencies:
  - `cd functions`
  - `npm install`
- Deploy or emulate as per your Firebase CLI workflow if you add functions.

## High-level architecture

### App bootstrap & global services (`lib/main.dart`)

`main.dart` is responsible for:
- Initializing Flutter bindings and wrapping app startup inside `SentryFlutter.init`.
- Initializing Firebase with `DefaultFirebaseOptions.currentPlatform`.
- Initializing `CallManager.instance` so incoming calls can be handled as soon as the app starts.
- Registering the FCM background handler and configuring `FirebaseMessaging` for web, Android, and iOS.
- Setting up `awesome_notifications` channels for:
  - Chat messages (`chat_messages`)
  - Stories (`stories`)
  - Calls (`calls`)
- Setting up `FlutterLocalNotificationsPlugin` and a global `navigatorKey` to deep-link into the app from notifications (e.g. directly into a chat on tap).
- Managing user presence via `UserStatusService` by observing `AppLifecycleState` (marking the user online/offline in Firestore when the app is foreground/background).
- Storing and refreshing FCM tokens in `users/{uid}.fcmTokens` , using `SecureStorageService` for local persistence.
- Providing `AuthService` to the widget tree via `ChangeNotifierProvider`.

Routing:
- `home: SplashScreen()` – splash and initial routing.
- Named routes:
  - `/auth` → `AuthGate` (auth state routing).
  - `/home` → `BottomNavScreen` (main tabbed interface).
- `onGenerateRoute` currently maps `/chat` to the *legacy* `ChatPage` by reconstructing `receiverUserId` and `receiverUserEmail` from `settings.arguments`.

### Domain & data model layer (`lib/model/` and `lib/models/`)

Core chat domain types live in `lib/model/`:
- `message.dart` – canonical message entity containing sender/receiver IDs, timestamps, message text, `MessageType`, optional `FileAttachment`, `replyToMessageId`, `isRead`, `isEdited`, and helper methods like `fromMap`/`toMap`.
- `message_type.dart` – enum for message types (`text`, `image`, `video`, `audio`, `document`, `other`, etc.), plus helpers like `fromMimeType` to map MIME types to message types.
- `file_attachment.dart` – metadata for attached files, including Firebase Storage URL, MIME type, size, derived flags (`isImage`, `isVideo`), and helpers such as `formattedFileSize`.
- `custom_message.dart` – used with `chatview` for non-standard message types such as contacts and locations, with `customType` and `extraData` maps.

Story-related models such as `story_item_model.dart` live under `lib/models/` and back the stories/status features.

### Service layer (`lib/services/`)

The app follows a service-oriented pattern where UI pages delegate most side effects and Firestore interactions to services.

Key services:

- **Auth services – `lib/services/auth/`**
  - `AuthService` – authentication logic (sign-in, sign-up, sign-out, user stream), exposed via Provider.
  - `AuthGate` – widget that routes based on auth state (logged in → app, not logged in → auth flow).
  - `login_or_register.dart` – orchestrates switching between login and registration forms.

- **Chat service – `lib/services/chat/chat_service.dart`**
  Central hub for all message-related operations using Firestore and Firebase Auth.
  - Message sending:
    - `sendTextMessage(receiverId, message)` – standard text messages.
    - `sendFileMessage(receiverId, fileAttachment, textMessage?)` – file or media messages with optional caption.
    - `sendContactMessage(...)` and `sendLocationMessage(...)` – encode richer payloads using `CustomMessage` and `ChatUser` from `chatview`.
    - `sendReplyMessage(...)` – message replies/quoting.
    - `createGroupChat(...)` – creates or reuses group chat rooms with `members`, `chatType: group`, metadata, etc.
  - Persistence helpers:
    - `_sendMessageToFirestore` – writes `Message.toMap()` into `chat_rooms/{chatRoomId}/messages` and updates parent chat room metadata.
    - `_sendCustomMessageToFirestore` – writes `CustomMessage`-backed messages but also maintains legacy `Message` metadata so unread counts, last message, etc. stay consistent.
    - `_updateChatRoomMetadata` – maintains `members`, `lastMessage`, `lastActivity`, `messageCount`, `fileCount`, and `chatType` for group rooms.
  - Reading and search:
    - `getMessagesStream(userId, otherUserId)` – typed stream of `Message`s ordered by timestamp.
    - `getMessages(userId, otherUserId)` – legacy raw `QuerySnapshot` stream.
    - `searchMessages(chatRoomId, query, type?)` – searches the latest messages (by text or file name) in a given room.
  - Unread and read state:
    - `_incrementUnreadCount(chatRoomId, receiverId)` – maintains per-user unread counts in `chat_rooms/{id}.unreadCount`.
    - `getUnreadMessageCount(chatRoomId, currentUserId)` – counts unread documents for the user.
    - `markMessagesAsRead(chatRoomId, currentUserId)` – marks all messages where `receiverId == currentUserId` as read and resets the unread counter.
  - Notifications:
    - `_sendNotificationToReceiver(receiverId, message)` – optional FCM push flow using an FCM server key (currently an empty placeholder constant); gracefully no-ops if the key is not configured.
    - `showMessageNotification(...)` – delegates to `NotificationService` for local notifications (used to show WhatsApp-style unread badges and message previews).

- **File services – `lib/services/file/`**
  These services implement a full file sharing pipeline on top of Firebase Storage and Firestore.
  - `file_service.dart` – core upload/download/cache/delete logic:
    - Uploads validated files to `chat_files/{chatRoomId}/{fileId.ext}` with retries and progress callbacks.
    - Stores metadata in `files/{fileId}` including `chatRoomId` and `messageId`.
    - Provides `downloadFile` with caching under `ApplicationDocumentsDirectory` (`downloads/` + `file_cache/` folders) and cache cleanup routines.
    - Deletes files and thumbnails from Storage and updates Firestore `status` and `deletedAt` fields.
  - `file_security_service.dart` and `validation_result.dart` – MIME/type/size validation, safe extensions, and error reporting.
  - `file_compression_service.dart` and `thumbnail_service.dart` – image/video compression, thumbnail generation, and optimization helpers.
  - `ai_file_organizer.dart` – higher-level organization/search logic for files (used by `ai_file_organizer_widget.dart`).
  - `web_file_stub.dart` – web-specific stub implementation for unsupported file system operations.

- **Call services – `lib/services/call/`**
  - `call_manager.dart` – global orchestrator for incoming/outgoing calls, wired early in `main()`.
  - `call_service.dart` – handles call setup, signaling, and persistence (e.g. Firestore `callHistory` collection).
  - `call_models.dart` – typed models for call sessions and participants.

- **User & presence services – `lib/services/user/`**
  - `user_status_service.dart` – tracks online/offline state in Firestore and is invoked from `MyApp` lifecycle callbacks.
  - `contact_service.dart` – queries and manages contacts/users from Firestore for the contact picker.

- **Other cross-cutting services**
  - `notification_service.dart` – wraps `awesome_notifications` and `flutter_local_notifications` to create consistent notification experiences and deep-link navigation payloads.
  - `connectivity_service.dart` – uses `connectivity_plus` to expose a connection status stream, driving UI indicators (e.g. in ChatView and app bars).
  - `secure_storage_service.dart` – wraps `flutter_secure_storage` for securely storing user IDs, FCM tokens, and other sensitive identifiers.
  - `story/story_service.dart` & `story_viewer.dart` – manages ephemeral story/status posts and playback.
  - `error_handler.dart` – centralized hooks for error capture, often forwarding to Sentry.

### UI components (`lib/components/`)

This directory holds most reusable UI building blocks. High-impact ones for the chat, media, and file workflows:

- **Chat rendering**
  - `chat_bubble.dart` – primary message bubble renderer for the legacy chat page:
    - Handles `MessageType.text`, `audio`, `image`, `video`, `document`, `location`, and `contact`.
    - Integrates specialized widgets for audio (`AudioMessageWidget`), video (`VideoMessageWidget`), contacts (`ContactMessageWidget`), locations (`LocationMessageWidget`), and generic file previews (`FilePreviewWidget`).
    - Supports swipe-to-reply, long-press reactions, read markers, and timestamp formatting.
  - `custom_message_bubbles.dart` – additional custom bubble layouts for ChatView-based screens.
  - `user_status_indicator.dart` – shows online/offline state for a user based on `UserStatusService`.

- **File sharing & media**
  - `file_picker_widget.dart`, `file_selection_dialog.dart` – entry points for picking files with different sources (photos/videos, documents, etc.).
  - `file_preview_widget.dart`, `file_icon_widget.dart`, `file_progress_indicator.dart`, `file_status_monitor.dart` – composable widgets for showing thumbnails/icons, progress, and status.
  - `audio_message_widget.dart`, `voice_recorder.dart`, `voice_message_widget.dart` – capturing and playing back audio messages.
  - `video_message_widget.dart` – inline video previews that then delegate to `video_player_screen.dart` for full-screen playback.
  - `ai_file_organizer_widget.dart` – UI on top of `ai_file_organizer.dart` for intelligent organization of shared files in a chat.

- **General app UI**
  - `bottom_navigation_bar.dart` – bottom nav used by `BottomNavScreen`.
  - `app_logo.dart`, `my_button.dart`, `uihelper.dart`, etc. – shared UI helpers and branding.

### Screens/pages (`lib/pages/`)

High-level layout:

- **Auth & entry**
  - `splash_screen.dart` – initial loading and routing to either auth or home based on user state.
  - `login_page.dart`, `register_page.dart`, `login_or_register.dart` – authentication flows.

- **Main shell & navigation**
  - `bottomNav_screen.dart` – root screen after login that manages tabs (chats, calls, stories, settings, etc.).
  - `home_page.dart` – main chat list with unread badges, last message previews, and presence indicators.

- **Chat**
  - `chat_page.dart` – original chat screen using custom UI (`ChatBubble`, etc.), still used for `/chat` route in `main.dart`.
  - `chat_page_chatview.dart` – new chat screen built on top of the `chatview` package:
    - Owns a `ChatController` and subscribes to `ChatService.getMessagesStream`.
    - Translates `Message`/`CustomMessage` into ChatView models.
    - Handles typing indicators, replying, attachments, and unread→read transitions.
    - Contains the real-time listener and `_markMessagesAsRead` logic described in `CHAT_MESSAGING_FIX.md`.

- **Contacts & groups**
  - `contact_screen.dart`, `add_contact_screen.dart`, `contact_share_page.dart` – selecting and sharing contacts; these call into `ChatService.sendContactMessage` and manage navigation into chat screens.
  - `create_group_page.dart`, `group_chat_page.dart` – group chat creation and interaction, using `ChatService.createGroupChat` and multi-member `chat_rooms`.

- **Media & location**
  - `image_viewer_page.dart`, `image_viewer_screen.dart` – full-screen image viewers for message attachments.
  - `video_player_screen.dart` – full-screen video player for video messages.
  - `location_share_page.dart`, `map_preview_page.dart` – location picking and viewing (backed by `geolocator`, `geocoding`, `flutter_map`).

- **Calls, stories, and profile**
  - `call_screen.dart`, `call_screen_widget.dart`, `incoming_call_dialog.dart` – UI around voice/video calls.
  - `story_upload_page.dart`, `story_viewer.dart`, `story_item_model.dart` – uploading and viewing ephemeral story content.
  - `profile_screen.dart`, `profile_screen2.dart`, `user_profile_page.dart`, `setting_screen.dart`, `setting_screen2.dart` – profile, settings, and debug/testing screens (some of which expose Sentry test events, connectivity status, etc., as described in `CHATVIEW_MIGRATION_README.md`).

## Data model & Firebase layout

Firestore collections and rules are documented in `Md files/DEVELOPMENT_SUMMARY.md`, `Md files/FIRESTORE_RULES.md`, and `Md files/CHAT_MESSAGING_FIX.md`. The effective shape used by the runtime code is:

- `users/{userId}`
  - Basic profile data (email, display info).
  - Presence fields (online/offline, last seen) managed by `UserStatusService`.
  - `fcmTokens: []` – list of device tokens populated in `MyApp._initNotificationsAndPermissions`.

- `chat_rooms/{chatRoomId}`
  - `members: [uid1, uid2, ...]` – sorted participant IDs; used in security rules and for constructing room IDs.
  - `chatType: 'direct' | 'group'` and group metadata (`groupName`, `groupDescription`, `groupAvatar`, `memberCount`).
  - `lastMessage` – full `Message` map for quick list rendering.
  - `lastActivity` – timestamp for sorting recent chats.
  - `messageCount`, `fileCount` – usage metrics.
  - `unreadCount: { userId: number }` – per-user unread counts.
  - Subcollections:
    - `messages/{messageId}` – individual chat messages (see `Message.toMap()` for fields such as `senderId`, `receiverId`, `message`, `timestamp`, `type`, `fileAttachment`, `isRead`, `replyToMessageId`, and custom contact/location payloads).
    - `typing/{typingId}` – typing indicator docs (used by ChatView and presence/typing features).
    - `media/{mediaId}` and `status/{statusId}` – optional nested collections for rich content and status updates.

- `files/{fileId}`
  - File metadata produced by `FileAttachment.toMap()` plus linkage (`chatRoomId`, `messageId`) and security-related fields like `allowedUsers`, `status`, and timestamps.

- `callHistory/{callId}`
  - Records call sessions with `callerId`, `receiverId`, timestamps, and status fields (consult call services for details).

Firestore security rules in `Md files/FIRESTORE_RULES.md` enforce that:
- Only authenticated users can read/write.
- Chat rooms, nested messages, typing, media, and status documents are only accessible to participants in `members` for that room.
- `users` docs are owner-writable but readable by any authenticated user.
- `files` and `callHistory` documents are protected by `allowedUsers`/caller/receiver ownership checks.

When modifying Firestore access patterns, keep the rules file and the actual paths (`chat_rooms/{id}/messages`, `typing`, `media`, `files`, `callHistory`) in sync.

## Notifications, presence, and calls

- **Notifications**
  - FCM is used to distribute push notifications. Tokens are stored per user in `users/{uid}.fcmTokens` and refreshed on token changes.
  - Local notifications are handled via `FlutterLocalNotificationsPlugin` and `awesome_notifications`.
  - `NotificationService` abstracts channel keys, payloads (e.g. `chatRoomId`, `receiverId`, `receiverEmail`), and deep linking back into `ChatPage` via the global `navigatorKey`.
  - In `ChatService`, the FCM server key is intentionally empty; to enable server-side FCM pushes, update that constant and follow the instructions in `Md files/CHAT_MESSAGING_FIX.md`.

- **Presence**
  - `MyApp` implements `WidgetsBindingObserver` and calls `UserStatusService().setUserOnline()` when the app is resumed and `setUserOffline()` when backgrounded or disposed.
  - UI widgets such as `user_status_indicator.dart` consume this status to show online/offline presence in chats and contact lists.

- **Calls**
  - `CallManager` is initialized before `runApp` so it can listen for incoming call events and potentially display UI from the notification context.
  - Call-related UI lives under `lib/components/call/` and `lib/pages/call_screen.dart`, while persistence and signaling are managed by `lib/services/call/`.

## Testing notes

- `integration_test/file_sharing_test.dart` validates file picker and selection flows in isolation by embedding `FileSelectionDialog`, `ChatFilePickerButton`, and `CompactFilePicker` in minimal `MaterialApp` scaffolds.
- `test/services/file_service_test.dart` focuses on the file upload/download path and should be extended if you add new validation or metadata behaviors in `FileService`.
- When adding new services that use Firebase, prefer to design them so they can be constructed with injected dependencies or run in a `runZonedGuarded`/fake environment, to keep tests decoupled from live Firebase where possible.
