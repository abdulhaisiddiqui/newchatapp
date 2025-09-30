rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // -----------------------------
    // Users Collection
    // -----------------------------
    match /users/{userId} {
      allow read: if request.auth != null; // Anyone logged in can see basic profiles
      allow write: if request.auth != null && request.auth.uid == userId; // Only owner can update
    }

    // -----------------------------
    // Chat Rooms & Messages
    // -----------------------------
    match /chat_rooms/{roomId} {
      // A user can read the chat room doc only if they are a member
      allow read, write: if request.auth != null
        && request.auth.uid in resource.data.members;

      // Nested messages inside each chat room
      match /messages/{msgId} {
        allow read, write: if request.auth != null
          && request.auth.uid in get(/databases/$(database)/documents/chat_rooms/$(roomId)).data.members;
      }

      // Typing indicators inside chat room
      match /typing/{typingId} {
        allow read, write: if request.auth != null
          && request.auth.uid in get(/databases/$(database)/documents/chat_rooms/$(roomId)).data.members;
      }

      // Media attachments inside chat room
      match /media/{mediaId} {
        allow read, write: if request.auth != null
          && request.auth.uid in get(/databases/$(database)/documents/chat_rooms/$(roomId)).data.members;
      }

      // Status updates (like WhatsApp-style status)
      match /status/{statusId} {
        allow read, write: if request.auth != null
          && request.auth.uid in get(/databases/$(database)/documents/chat_rooms/$(roomId)).data.members;
      }
    }

    // -----------------------------
    // File Attachments (shared outside chat rooms)
    // -----------------------------
    match /files/{fileId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.auth.uid in resource.data.allowedUsers;
    }

    // -----------------------------
    // Call History
    // -----------------------------
    match /callHistory/{callId} {
      allow read, write: if request.auth != null
        && (request.auth.uid == resource.data.callerId
          || request.auth.uid == resource.data.receiverId);
    }

  }
}