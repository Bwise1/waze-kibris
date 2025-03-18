import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:waze_kibris/common.dart';

final getIt = GetIt.instance;

class DI {
  DI._();

  static Future<void> initializeObjects(WazeEnv env) async {
    final httpClient = HttpClient(dio: Dio(BaseOptions(baseUrl: env.apiUrl)));
    final thirdPartyHttp = ThirdPartyHttpClient(dio: Dio());
    final localStorage = LocalStorage();
    await localStorage.initializePrefs();
    final dio = Dio(
      BaseOptions(
        baseUrl: env.apiUrl,
        headers: {
          'X-Request-Source': 'postman',
          'Content-Type': 'application/json',
        },
      ),
    );

    getIt
      ..registerLazySingleton<HttpClient>(() => httpClient)
      ..registerLazySingleton<ThirdPartyHttpClient>(() => thirdPartyHttp)
      ..registerLazySingleton<ILocalStorage>(() => localStorage)
      ..registerLazySingleton<Dio>(() => dio);

    await getIt.allReady();
  }

  static Future<void> reset({bool clearStorage = true}) async {
    if (clearStorage) {
      //await getIt<ILocalStorage>().clear();
    }
  }
}
