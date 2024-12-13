import 'package:flash/flash_helper.dart';
import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/l10n/l10n.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: styles.theme.data(),
      routerConfig: appRouter,
      builder: (context, child) {
        return LayoutBuilder(
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
        );
      },
    );
  }
}
