# Firebase Auth setup

Manual steps in [Firebase Console](https://console.firebase.google.com/) and for the Go API. The app uses **Firebase ID tokens**; the API verifies them with the Firebase Admin SDK and issues your existing JWT + refresh tokens.

**These files are not committed** (`.gitignore`): `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`, `firebase.json`. After cloning, add them using the steps below or run `dart pub global activate flutterfire_cli` and `flutterfire configure`.

**Mapbox** public tokens are also kept out of Git — see [MAPBOX_LOCAL.md](MAPBOX_LOCAL.md).

**Push (FCM):** device token registration and server send — see [FCM_SETUP.md](FCM_SETUP.md).

## 1. Firebase project (console)

1. Create or select a project.
2. Add **iOS** and **Android** apps with the same bundle / application IDs as this repo (`ios/Runner`, `android/app` flavors).
3. **Android flavors:** `development` uses `applicationId` `…waze_kibris.dev`, `staging` uses `…waze_kibris.stg`, `production` uses `…waze_kibris`. `google-services.json` must include a **client** entry for **each** package name, or Gradle fails with “No matching client found”. Prefer registering each Android app in Firebase and re-downloading the merged JSON; the repo may ship merged entries for local builds.
4. Download **`GoogleService-Info.plist`** → `ios/Runner/` and **`google-services.json`** → `android/app/`.
5. **Authentication → Sign-in method**: enable **Google** and **Apple** (Apple needs an Apple Developer Services ID / key; see [Firebase Apple sign-in](https://firebase.google.com/docs/auth/ios/apple)).
6. Ensure `lib/firebase_options.dart` matches your project (`flutterfire configure` if you change projects).

### Android: SHA-1 (required for Google Sign-In)

If Google Sign-In fails with **DEVELOPER_ERROR**, **ApiException: 10**, or “did not return an idToken”, add the **SHA-1** (and SHA-256) for the keystore you use to build:

```bash
cd android && ./gradlew signingReport
```

In **Firebase Console → Project settings → Your apps**, open each **Android** app (prod / `.dev` / `.stg`) and add the **debug** certificate fingerprint. Re-download `google-services.json` after adding apps if needed.

### iOS extras

- **Sign In with Apple** capability in Xcode for the Runner target (required if you ship other third-party sign-in on iOS).
- **Google Sign-In URL scheme**: the downloaded `GoogleService-Info.plist` should include `REVERSED_CLIENT_ID`. Add a **URL type** in Xcode using that value so Google OAuth can return to the app (see [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios/start-integrating)).

## 2. API: service account (server only)

1. Firebase Console → Project settings → **Service accounts** → **Generate new private key** (JSON).
2. **Do not commit** this file. On the server set either:
   - `FIREBASE_CREDENTIALS_PATH=/absolute/path/to/serviceAccount.json`, or  
   - `GOOGLE_APPLICATION_CREDENTIALS` (standard Google ADC) to that path.

Without one of these, the API logs that Firebase Auth is disabled and `POST /auth/firebase/login` returns an error.

## 3. User migration (email link)

The API links **`user_auth_providers`** with `auth_provider = 'firebase'` and `auth_provider_id = <Firebase uid>`.

On **first** Firebase login:

- If that Firebase `uid` is unknown but the **email** matches an existing user (email OTP, legacy Google, etc.), a new row is inserted for `firebase` + `uid` on the **same** user.
- Existing `google` rows are left in place until all old clients are gone.

Optional one-off: backfill `firebase` provider rows from a script; not required if users sign in once with Firebase.

## 4. Legacy mobile Google token route

Clients that still send a **Google OAuth ID token** (not Firebase) can use:

- `POST /auth/google/login` with JSON `{ "id_token": "..." }` or `{ "token": "..." }`.

New app builds should use **`POST /auth/firebase/login`** with `{ "id_token": "<Firebase JWT>" }` after `FirebaseAuth` sign-in.
