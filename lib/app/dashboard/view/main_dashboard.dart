import 'package:flutter/cupertino.dart';
import 'package:waze_kibris/common.dart';

import '../../profile/view/profile_main.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(


        child: LazyIndexedStack(children: [
          ProfileMainScreen()
          ,Text("data",style: styles.typography.h1.textColor(styles.theme.text),)],));
  }
}
