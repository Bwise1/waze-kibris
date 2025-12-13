import 'package:flutter/material.dart';
import 'package:waze_kibris/app/report/view/report_screen.dart';
import 'package:waze_kibris/common.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: styles.theme.background,

      // bottomNavigationBar: HomeBottomNav(
      //   index: index,
      //   onChanged: (int index) {
      //     setState(() {
      //       this.index = index;
      //     });
      //   },
      // ),
      body: LazyIndexedStack(
        index: index,
        children: [
          MainDashboard(),
          const ReportScreen(),
          // MapPolyScreen(), //
          const ProfileMainScreen(),
        ],
      ),
    );
  }
}
