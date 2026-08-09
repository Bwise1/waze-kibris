class StoreKeys {
  static const String wazeToken = 'waze_token';
  static const String wazeRefreshToken = 'waze_refresh_token';

  /// Last successfully fetched profile, as JSON. Lets a launch with no
  /// network (dead DNS, airplane mode, slow Wi-Fi handoff) show the real
  /// logged-in user instead of "Guest" — a valid token plus a failed lookup
  /// is offline, not logged out.
  static const String cachedUser = 'waze_cached_user';
}
