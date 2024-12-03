class AppService {
  static AppService? _instance;
  static AppService get instance {
    _instance ??= AppService._();
    if (_instance != null) _instance!.init();
    return _instance!;
  }

  AppService._();

  final bool isDebug = false;
  final bool useNavRail = false;
  get shouldUseNavRail => useNavRail;

  void init() {}
}
