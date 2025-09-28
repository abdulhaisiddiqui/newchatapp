# ChatApp - Modern Messaging Platform

![ChatApp Logo](assets/images/Message.png)

## Project Overview

ChatApp is a feature-rich messaging application built with Flutter and Firebase, designed to provide a seamless communication experience across multiple platforms. The application enables users to connect, chat, and share files in real-time with an intuitive and modern interface.

### Key Features

- **Real-time Messaging**: Instant message delivery and read receipts
- **User Authentication**: Secure login with email/password and social providers
- **File Sharing**: Support for images, videos, documents, and other file types
- **User Profiles**: Customizable user profiles with status updates
- **Chat Organization**: Organized conversations with search functionality
- **Cross-Platform**: Works on iOS, Android, and web platforms

### Architecture

ChatApp follows a clean architecture pattern with:
- Firebase Backend (Authentication, Firestore, Storage)
- Flutter UI Framework
- Provider for State Management

## Getting Started

### Prerequisites

- Flutter SDK (version 3.8.0 or higher)
- Dart SDK (version 3.0.0 or higher)
- Firebase account
- Android Studio / VS Code with Flutter plugins

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/chatapp.git
   cd chatapp
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a new Firebase project
   - Add Android/iOS apps to your Firebase project
   - Download and place the configuration files:
     - `google-services.json` for Android
     - `GoogleService-Info.plist` for iOS
   - Enable Authentication, Firestore, and Storage services

4. **Run the application**
   ```bash
   flutter run
   ```

### Environment Variables

Create a `.env` file in the project root with the following variables:
```
FIREBASE_API_KEY=your_api_key
FIREBASE_APP_ID=your_app_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_PROJECT_ID=your_project_id
```

## Usage Instructions

### Basic Commands

- **Start the app**: `flutter run`
- **Build for release**: `flutter build apk` (Android) or `flutter build ios` (iOS)
- **Run tests**: `flutter test`

### Common Workflows

#### User Registration and Login

1. Launch the app
2. Choose "Register" to create a new account
3. Enter your email, password, and username
4. Verify your email (if required)
5. Log in with your credentials

#### Sending Messages

1. Select a contact from the home screen
2. Type your message in the text field
3. Press the send button or use the Enter key
4. For file attachments, tap the attachment icon and select files

#### File Sharing

1. In a chat, tap the attachment icon
2. Select the file type (image, video, document)
3. Choose the file from your device
4. Add an optional caption
5. Send the file

### Screenshots

![Login Screen](assets/images/Login_text.png)
![Chat Interface](assets/images/Message.png)
![Settings Screen](assets/images/settings.png)

## Development Guidelines

### Contribution Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow the [Flutter style guide](https://flutter.dev/docs/development/tools/formatting)
- Write meaningful commit messages
- Include comments for complex logic
- Maintain test coverage for new features

### Testing Procedures

- Unit tests for services and models
- Widget tests for UI components
- Integration tests for user flows
- Run tests before submitting PRs: `flutter test`

### Build and Deployment

#### Android
```bash
flutter build apk --release
```

#### iOS
```bash
flutter build ios --release
```

## Project Information

### Dependencies

- Flutter SDK: ^3.8.1
- Firebase Core: ^3.15.2
- Firebase Auth: ^5.7.0
- Cloud Firestore: ^5.6.12
- Firebase Storage: ^12.4.10
- Provider: latest
- File Picker: ^8.0.0+1
- Path Provider: ^2.1.1
- Flutter SVG: ^2.0.10+1
- Image Picker: ^1.2.0

### License

This project is licensed under the MIT License - see the LICENSE file for details.

### Roadmap

- [ ] Group chat functionality
- [ ] End-to-end encryption
- [ ] Voice and video calls
- [ ] Message reactions and replies
- [ ] Cross-platform desktop support

### Known Issues and Troubleshooting

- **Issue**: App crashes when uploading large files
  **Solution**: Ensure files are under 50MB and have proper permissions

- **Issue**: Messages not appearing in real-time
  **Solution**: Check your internet connection and Firebase rules

## Support

### Contact Information

For support or inquiries, please contact:
- Email: support@chatapp.com
- Twitter: @ChatAppSupport

### Issue Reporting

1. Check existing issues on GitHub
2. Use the issue template to report new issues
3. Include detailed steps to reproduce the problem
4. Add screenshots or videos if applicable

### Community Guidelines

- Be respectful and inclusive
- Help others when possible
- Follow the code of conduct
- Participate in discussions constructively
