import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// OAuth 2.0 **Web client** ID from Firebase (Project settings → Your apps, or
/// Authentication → Google → Web client ID). Required on Android so Google
/// Sign-In returns an ID token for Firebase.
///
/// Same value as `oauth_client` / `other_platform_oauth_client` in
/// `android/app/google-services.json` for this project.
const String _kGoogleWebClientId =
    '819487009351-nv8sv2jm0f5cfn7eedfeinrhgrfnnj9q.apps.googleusercontent.com';

/// Firebase Auth sign-in for Google and Apple.
/// Returns a Firebase ID token for the backend.
class FirebaseSocialAuthService {
  FirebaseSocialAuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
              serverClientId: _kGoogleWebClientId,
            );

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Future<String?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore if no previous session.
    }
    final account = await _googleSignIn.signIn();
    if (account == null) {
      return null;
    }
    final googleAuth = await account.authentication;
    if (googleAuth.idToken == null) {
      throw StateError(
        'Google Sign-In did not return an idToken. Add your debug/release '
        'SHA-1 in Firebase Console (Project settings → Your apps → '
        'Android), and ensure the Web client ID above matches Firebase.',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw StateError(
        'Firebase sign-in failed: ${e.code} ${e.message ?? ''}'.trim(),
      );
    }
    return _auth.currentUser?.getIdToken();
  }

  /// Apple is only on iOS (often required when other social logins exist).
  Future<String?> signInWithApple() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError('Sign in with Apple is only available on iOS');
    }
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final idToken = appleCredential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Apple Sign In did not return an identity token');
    }
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      accessToken: appleCredential.authorizationCode,
    );
    await _auth.signInWithCredential(oauthCredential);
    return _auth.currentUser?.getIdToken();
  }
}
