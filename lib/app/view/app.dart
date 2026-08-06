import 'package:flash/flash_helper.dart';
import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/repositories/auth_repository.dart';
import 'package:waze_kibris/core/repositories/report_repository.dart';
import 'package:waze_kibris/core/repositories/group_repository.dart';
import 'package:waze_kibris/core/bloc/groups/groups_bloc.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';
import 'package:waze_kibris/l10n/l10n.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => IAuthRepository()),
        RepositoryProvider<ReportRepository>(
          create: (_) => ReportRepositoryImpl(),
        ),
        RepositoryProvider<GroupRepository>(
          create: (_) => GroupRepositoryImpl(),
        ),
        // WebSocket service (backed by DI / GetIt)
        RepositoryProvider<WebSocketService>(
          create: (_) => getIt<WebSocketService>(),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: styles.theme.data(),
        routerConfig: appRouter,
        builder: (context, child) {
          return MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>(
                create: (context) => AuthBloc(
                  authRepository: context.read<AuthRepository>(),
                )..add(AuthEvent.getProfileRequested()),
              ),
              BlocProvider<ReportsBloc>(
                create: (context) => ReportsBloc(
                  reportRepository: context.read<ReportRepository>(),
                  authBloc: context.read<AuthBloc>(),
                  webSocketService: context.read<WebSocketService>(),
                ),
              ),
              BlocProvider<GroupsBloc>(
                create: (context) {
                  final authBloc = context.read<AuthBloc>();
                  return GroupsBloc(
                    groupRepository: context.read<GroupRepository>(),
                    webSocketService: context.read<WebSocketService>(),
                    currentUserId: () {
                      final s = authBloc.state;
                      return s is AuthSuccess ? s.user?.id : null;
                    },
                  );
                },
              ),
            ],
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.deferToChild,
                  onTap: () {
                    final focus = FocusScope.of(context);
                    if (!focus.hasPrimaryFocus) {
                      focus.focusedChild?.unfocus();
                    }
                  },
                  child: Toast(
                    navigatorKey: navigatorKey,
                    child: child ?? const SizedBox(),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
