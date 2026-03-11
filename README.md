# Smart Bus Tracking (project_spt)

Flutter mobile app for student/driver bus tracking with Firebase realtime updates and backend API integration.

## Prerequisites

- Flutter SDK (stable)
- Dart SDK (bundled with Flutter)
- Android Studio / VS Code
- JDK 17 for Android build tools
- Firebase project configuration files

## Setup

1. Clone the repository.
2. Run `flutter pub get`.
3. Ensure Firebase config files exist:
   - `android/app/google-services.json`
   - iOS Firebase config if building iOS
4. Verify backend endpoint and API key are configured in:
   - `lib/service/api_service.dart`

## Run

- Android: `flutter run`
- iOS: `flutter run -d ios` (macOS + Xcode required)

## Quality checks

- Analyze: `flutter analyze`
- Tests: `flutter test`

## Android release signing

Release signing supports `android/key.properties` with:

- `storeFile`
- `storePassword`
- `keyAlias`
- `keyPassword`

If `key.properties` is missing, local release build falls back to debug signing for development convenience.

## Notes

- `android/build/` outputs are generated artifacts and should not be committed.
- This project currently uses realtime location, Firebase notifications, and role-based student/driver flows.
