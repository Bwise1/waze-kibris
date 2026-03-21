# Firebase Cloud Messaging (FCM)

The app registers device tokens with your API after login; the Go server can send pushes via `FirebaseMessaging` (same service account as Firebase Auth).

## 1. Apply database migration (API)

Run the SQL in the API repo:

`internal/db/migrations/create_user_fcm_tokens.sql`

against your Postgres database (same process you use for other migrations).

## 2. Server

- Uses the **same** Firebase service account JSON as Auth (`FIREBASE_CREDENTIALS_PATH` / `GOOGLE_APPLICATION_CREDENTIALS`).
- On startup you should see: `Firebase Cloud Messaging client initialized (push send enabled)`.
- **Endpoints** (Bearer JWT):
  - `POST /user/fcm-token` — `{ "token": "<fcm registration token>", "platform": "android" | "ios" | "web" }`
  - `DELETE /user/fcm-token` — optional body `{ "token": "..." }` to drop one device; **empty body** removes **all** tokens for the user (logout).

**Sending from Go:** call `api.SendFCMToUser(ctx, userID, title, body, dataMap)` from `internal/http/rest/fcm_send.go` (e.g. after a new group message).

## 3. Firebase Console

1. **Project settings → Cloud Messaging** — ensure Cloud Messaging API is enabled for the project (Google Cloud).
2. **iOS:** Upload an **APNs authentication key** (.p8) or certificates under Project settings → Your apps → iOS app. Without this, iOS devices won’t receive remote notifications.
3. **Android:** `google-services.json` already links the app; no extra FCM server key in the client.

## 4. Xcode (iOS)

1. Open `ios/Runner.xcworkspace`.
2. **Signing & Capabilities** → **+ Capability** → **Push Notifications**.
3. Confirm **Background Modes** includes **Remote notifications** (Info.plist already lists `remote-notification` under `UIBackgroundModes`).

## 5. Flutter app

- Dependency: `firebase_messaging` (see `pubspec.yaml`). Run:

  ```bash
  flutter pub get
  ```

- **Background handler:** `lib/firebase_messaging_background.dart` — registered in `main.dart` / `main_development.dart` **before** `Firebase.initializeApp` is not required; order in repo is: `onBackgroundMessage` → `initializeApp` (both are valid per FlutterFire).
- **Runtime:** `PushNotificationService` requests notification permission (iOS + Android 13+), listens for token refresh, and calls `POST /user/fcm-token` when the user is logged in.
- **Logout:** `DELETE /user/fcm-token` with no body clears server-side tokens.

## 6. Test

1. Log in on a device; confirm API logs or DB row in `user_fcm_tokens`.
2. From Firebase Console → **Messaging** → compose a notification targeting your app (or call `SendFCMToUser` from Go with a test title/body).

## 7. Foreground behavior

When the app is open, `FirebaseMessaging.onMessage` fires; the sample logs to debug console. To show a banner while foregrounded, wire `flutter_local_notifications` (already in the project) inside that listener.
