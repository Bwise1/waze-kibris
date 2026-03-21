# Mapbox token (local only)

The **public** Mapbox access token (from [account.mapbox.com](https://account.mapbox.com/access-tokens/)) must not be committed. GitHub push protection blocks pushes that contain it.

## Android

Add to **`android/local.properties`** (already gitignored):

```properties
mapbox.access.token=PASTE_YOUR_PUBLIC_TOKEN_HERE
```

Or set **`MAPBOX_ACCESS_TOKEN`** in the environment when building (CI).

Gradle injects `mapbox_access_token` at build time (`android/app/build.gradle`).

## iOS

1. Copy the example file:

   ```bash
   cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
   ```

2. Edit **`ios/Flutter/Secrets.xcconfig`** and set **`MAPBOX_ACCESS_TOKEN=`** to your public token (one line, no spaces around `=`).

`Info.plist` reads `$(MAPBOX_ACCESS_TOKEN)` from this file via `ios/Flutter/Debug.xcconfig` / `Release.xcconfig`.

## Dart / `flutter run`

You can also pass the same token for Dart-side setup:

```bash
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=PASTE_YOUR_PUBLIC_TOKEN_HERE
```

See `lib/core/res/env.dart`.

## Token exposed in Git history?

1. **Rotate** the token in the Mapbox dashboard and use the new value only in local files above.
2. Remove secrets from history before pushing again — see GitHub’s [push protection](https://docs.github.com/code-security/secret-scanning/working-with-secret-scanning-and-push-protection/working-with-push-protection-from-the-command-line#resolving-a-blocked-push). For a feature branch, squashing to a single commit after cleaning files often clears the issue; otherwise use `git filter-repo` or similar.
