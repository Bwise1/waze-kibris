class AppService {

  AppService._();
  static AppService? _instance;
  static Future<AppService> get instance async {
    _instance ??= AppService._();
    if (_instance != null) _instance!.init();
    return _instance!;
  }

  final bool isDebug = false;
  final bool useNavRail = false;
  bool get shouldUseNavRail => useNavRail;

  void init() {}
}
