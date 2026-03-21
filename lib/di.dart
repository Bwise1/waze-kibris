import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:waze_kibris/app/dashboard/view/places_service.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';
import 'package:waze_kibris/core/services/auth_interceptor.dart';
import 'package:waze_kibris/core/services/firebase_social_auth_service.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';

final getIt = GetIt.instance;

class DI {
  DI._();

  static Future<void> initializeObjects(WazeEnv env) async {
    final localStorage = LocalStorage();
    await localStorage.initializePrefs();

    // Create Dio instance with base configuration
    final dio = Dio(
      BaseOptions(
        baseUrl: env.apiUrl,
        headers: {
          'X-Request-Source': 'postman',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Register dependencies in order
    getIt
      ..registerLazySingleton<ILocalStorage>(() => localStorage)
      ..registerLazySingleton<Dio>(() => dio)
      ..registerLazySingleton<FirebaseSocialAuthService>(
        FirebaseSocialAuthService.new,
      );

    // Create and register AuthRepository (needed by interceptor)
    final authRepository = IAuthRepository(
      dio: Dio(BaseOptions(baseUrl: env.apiUrl)),
      store: localStorage,
    );
    getIt.registerLazySingleton<AuthRepository>(() => authRepository);

    // Add auth interceptor to Dio
    final authInterceptor = AuthInterceptor(
      localStorage: localStorage,
      authRepository: authRepository,
    );
    dio.interceptors.add(authInterceptor);

    // Register remaining dependencies
    final httpClient = HttpClient(dio: dio);
    final thirdPartyHttp = ThirdPartyHttpClient(dio: Dio());

    // Derive WebSocket endpoint from API URL (https -> wss, + '/ws')
    final wsEndpoint = '${env.apiUrl.replaceFirst('http', 'ws')}/ws';
    final webSocketService = WebSocketService(wsEndpoint);

    getIt
      ..registerLazySingleton<HttpClient>(() => httpClient)
      ..registerLazySingleton<ThirdPartyHttpClient>(() => thirdPartyHttp)
      ..registerLazySingleton<PlacesService>(() => PlacesService(dio: dio))
      ..registerLazySingleton<WebSocketService>(() => webSocketService);

    await getIt.allReady();
  }

  static Future<void> reset({bool clearStorage = true}) async {
    if (clearStorage) {
      //await getIt<ILocalStorage>().clear();
    }
  }
}
