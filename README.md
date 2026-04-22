# SafeNest: AI-Based Child Safety System

This project is a multi-platform safety solution designed to protect children through real-time monitoring and AI analysis.

## 📱 Primary Project: Flutter Mobile Application
The active development codebase is located in the `/flutter_app` directory. This is a native Flutter application built for Android and iOS.

### Key Features (Flutter)
- **Firebase Real-Time Handshake**: Secure parent-child linking using dynamic 6-digit codes.
- **AI Safety Advisor**: Integrated Google Gemini 1.5 Flash for safety report analysis.
- **Live Location Sync**: Continuous background tracking with Firestore synchronization.
- **SOS Alert System**: High-priority emergency triggering with instant parent notification.

## 📦 Archived: React Web Application
The previous TypeScript/React implementation has been moved to `/react_web_archive`.
- **Purpose**: Reference for logic and UI prototypes.
- **Status**: Frozen.

## 🛠️ Technical Stack
- **Framework**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore)
- **AI**: Google Generative AI SDK
- **Architecture**: Service-based with Provider state management
