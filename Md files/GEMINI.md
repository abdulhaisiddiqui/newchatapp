# GEMINI Code Companion: Flutter Chat App

This document provides a comprehensive overview of the **Flutter Chat App (newchatapp)**, designed to give Gemini a deep understanding of the project's architecture, dependencies, and development conventions.

## 🚀 Project Overview

This is a feature-rich Flutter chat application that mirrors many functionalities of popular messaging apps like WhatsApp. It leverages a robust tech stack to deliver a seamless user experience across multiple platforms (Android, iOS, and Web).

- **Purpose**: To provide a real-time, multimedia chat experience with features like instant messaging, file sharing, voice/video calls, and user presence indicators.
- **Architecture**: The app follows a standard Flutter project structure, with a clear separation of concerns between UI (pages and components), business logic (services), and data models. State management is handled using the `provider` package, ensuring a predictable and maintainable data flow.
- **Tech Stack**:
  - **Frontend**: Flutter (Dart)
  - **Backend**: Firebase (Authentication, Firestore, Storage)
  - **State Management**: `provider`
  - **Real-time Communication**: Firestore streams
  - **Notifications**: `awesome_notifications` and Firebase Cloud Messaging (FCM)
  - **Error Tracking**: Sentry
  - **UI**: Material Design, with a rich set of custom widgets and animations.

## 🛠️ Building and Running

### Prerequisites

- Flutter SDK (version 3.8.1 or higher)
- A configured Firebase project with Authentication, Firestore, and Storage enabled.

### Commands

- **Install Dependencies**:
  ```bash
  flutter pub get
  ```
- **Run the App**:
  ```bash
  flutter run
  ```
- **Run Tests**:
  ```bash
  flutter test
  ```

## 📜 Development Conventions

- **Code Style**: The project follows the standard Dart and Flutter style guides, enforced by the `flutter_lints` package.
- **State Management**: `ChangeNotifierProvider` from the `provider` package is the primary mechanism for managing app state.
- **File Naming**: Files are named using `snake_case`, and widgets are typically in their own files.
- **Commit Messages**: While not explicitly defined, a review of the project's documentation suggests that commit messages should be descriptive and reference the feature or bug fix they address.
- **Error Handling**: The app uses `Sentry` for crash reporting and error monitoring. Exceptions should be caught and reported to Sentry where appropriate.

## 📄 Key Files

- **`pubspec.yaml`**: Defines all project dependencies, including Firebase, Sentry, and a wide array of UI and utility packages. It also configures project assets and custom fonts.
- **`lib/main.dart`**: The entry point of the application. It initializes Firebase, Sentry, and the notification services. It also sets up the main `MaterialApp` widget and defines the app's routes.
- **`lib/services/auth/auth_gate.dart`**: Manages the user's authentication state, redirecting them to the appropriate screen (login or home) based on whether they are signed in.
- **`lib/pages/chat_page_chatview.dart`**: The main chat screen, where users can send and receive messages.
- **`lib/services/chat/chat_service.dart`**: Contains the business logic for sending and receiving messages, managing chat rooms, and interacting with Firestore.
- **`README.md`**: The primary source of information for new developers, providing a high-level overview of the project, its features, and how to get started.
