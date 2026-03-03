import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/auth/auth_state.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';

class ReportEventModal extends StatelessWidget {
  const ReportEventModal({super.key});

  static List<Map<String, dynamic>> reports = [
    {
      'name': 'Police',
      'type': ReportType.police.name,
      'icon': SvgPicture.asset(
        Assets.icons.reports.police,
      ),
      'isNewPage': false,
      'page': const ReportPoliceEventModal(),
    },
    {
      'name': 'Traffic',
      'type': ReportType.traffic.name,
      'icon': SvgPicture.asset(
        Assets.icons.reports.trafic,
      ),
      'isNewPage': false,
      'page': const ReportPoliceEventModal(),
    },
    {
      'name': 'Accident',
      'type': ReportType.accident.name,
      'icon': SvgPicture.asset(Assets.icons.reports.accident),
      'isNewPage': false,
      'page': const ReportPoliceEventModal(),
    },
    {
      'name': 'Alternate Route',
      'type': ReportType.alternateRoute.name,
      'icon': SvgPicture.asset(Assets.icons.reports.alterRoute),
      'isNewPage': true,
      'page': const ReportPoliceEventModal(),
    },
    {
      'name': 'Photo Sharing',
      'type': ReportType.photoSharing.name,
      'icon': SvgPicture.asset(Assets.icons.reports.sending),
      'isNewPage': true,
      'page': const ReportPoliceEventModal(),
    },
    {
      'name': 'Chat',
      'type': ReportType.photoSharing.name,
      'icon': SvgPicture.asset(Assets.icons.reports.chat),
      'isNewPage': true,
      'page': const ReportPoliceEventModal(),
    },
  ];
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        styles.insets.sm,
        styles.insets.sm,
        styles.insets.sm,
        styles.insets.sm + bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: styles.theme.grey.withValues(alpha: .3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Gap(styles.insets.xs),
          Text('What do you see', style: styles.typography.f.size(17).bold),
          Text(
            'Aid others by telling us what you see',
            style: styles.typography.caption.textColor(styles.theme.caption),
          ),
          Gap(styles.insets.xs),
          GridView.builder(
            itemCount: reports.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  if (reports[index]['isNewPage'] as bool) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pop(context);
                    CustomDialogRoutes.showBottomSheet<bool>(
                      context,
                      reports[index]['page'] as Widget,
                    );
                  }
                },
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: styles.theme.white,
                        borderRadius: BorderRadius.circular(styles.corners.sm),
                        boxShadow: styles.shadows.md,
                      ),
                      padding: EdgeInsets.all(styles.insets.sm),
                      child: reports[index]['icon'] as Widget,
                    ),
                    Gap(4),
                    Text(
                      reports[index]['name'] as String,
                      style: styles.typography.caption.bold.size(10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          Gap(styles.insets.xs),
        ],
      ),
    );
  }
}

class ReportPoliceEventModal extends StatefulWidget {
  const ReportPoliceEventModal({super.key});

  @override
  State<ReportPoliceEventModal> createState() => _ReportPoliceEventModalState();
}

class _ReportPoliceEventModalState extends State<ReportPoliceEventModal> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(
          AuthEvent.getUserCoordinateRequested(context: context),
        );
  }

  int? _selectedIndex;
  @override
  Widget build(BuildContext context) {
    // final userCoordinate = context.select((AuthBloc auth) => auth.state);

    final reports = <Map<String, dynamic>>[
      {
        'type': ReportType.police.name,
        'subType': 'police',
        'icon': SvgPicture.asset(
          Assets.icons.reports.police,
        ),
      },
      {
        'type': ReportType.traffic.name,
        'subType': 'patrol',
        'icon': SvgPicture.asset(
          Assets.icons.reports.patrol,
        ),
      },
      {
        'type': ReportType.accident.name,
        'subType': 'otherLane',
        'icon': SvgPicture.asset(Assets.icons.reports.accident),
      }
    ];
    return Padding(
      padding: EdgeInsets.all(styles.insets.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: styles.theme.grey.withValues(alpha: .3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Gap(styles.insets.xs),
          Text('Report Police', style: styles.typography.f.size(17).bold),
          Gap(styles.insets.xs),
          GridView.builder(
            itemCount: reports.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              return BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {},
                builder: (context, state) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: _selectedIndex == index
                                    ? styles.theme.secondary
                                    : styles.theme.white,
                                borderRadius:
                                    BorderRadius.circular(styles.corners.sm),
                                boxShadow: styles.shadows.md,
                              ),
                              padding: EdgeInsets.all(styles.insets.sm),
                              child: reports[index]['icon'] as Widget,
                            ),
                            Gap(4),
                            Text(
                              reports[index]['type'] as String,
                              style: styles.typography.caption.bold.size(10),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        Positioned(
                          right: 3,
                          child: Visibility(
                            visible: _selectedIndex == index,
                            child: Checkbox(
                              value: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              onChanged: (v) {},
                              activeColor: styles.theme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          Gap(styles.insets.sm),
          BlocBuilder<AuthBloc, AuthState>(
            // listener: (context, authState) {},
            builder: (authContext, authState) {
              return Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      text: 'Cancel',
                      bgColor: styles.theme.secondary,
                      textColor: styles.theme.primary,
                    ),
                  ),
                  Gap(styles.insets.xs),
                  Expanded(
                    child: BlocConsumer<ReportsBloc, ReportState>(
                      listener: (reportContext, state) {
                        if (state is ReportError) {
                          RSnackBar.error(state.message).show(context);

                          //this happens wen token has expired
                          // if (state.message == 'Exception: token-expired') {
                          //   context.go(ScreenPaths.signIn);
                          //   context.read<ReportsBloc>().add(
                          //         ReportsEvent.clearExpiredToken(),
                          //       );
                          // }
                        } else if (state is SubmitReportSuccess) {
                          Navigator.pop(context);
                          RSnackBar.success(state.message).show(context);
                          // Explicitly refresh reports after successful submission
                          // The bloc already calls getNearByReports, but ensure it uses current position
                          if (authState is UserCoordinate) {
                            reportContext.read<ReportsBloc>().add(
                                  ReportsEvent.getNearByReports(
                                    radius: 50,
                                    lat: authState.latitude.toString(),
                                    long: authState.longitude.toString(),
                                  ),
                                );
                          }
                        }
                        //this happens wen token has expired
                        // if (state.message == 'Exception: token-expired') {
                        //   context.go(ScreenPaths.signIn);
                        //   context.read<ReportsBloc>().add(
                        //         ReportsEvent.clearExpiredToken(),
                        //       );
                        // }
                      },
                      builder: (reportContext, state) {
                        return SubmitReportBTN(
                          onPressed: () {
                            // print(userCoordinate);

                            if (authState is UserCoordinate) {
                              debugPrint(
                                  '${authState.longitude} ${authState.latitude}');
                              reportContext.read<ReportsBloc>().add(
                                    ReportsEvent.submitReportRequested(
                                      longitude: authState.longitude,
                                      latitude: authState.latitude,
                                      type: reports[_selectedIndex ?? 0]['type']
                                          .toString(),
                                    ),
                                  );
                            }
                            // if (authState is UserCoordinate) {
                            //   print(authState.longitude);
                            //   reportContext.read<ReportsBloc>().add(
                            //         ReportsEvent.submitReportRequested(
                            //           longitude: authState.longitude,
                            //           latitude: authState.latitude,
                            //           type: reports[_selectedIndex ?? 0]['type']
                            //               .toString(),
                            //         ),
                            //       );
                            // }
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class SubmitReportBTN extends StatelessWidget {
  const SubmitReportBTN({
    this.onPressed,
    super.key,
  });
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportsBloc, ReportState>(
      listener: (context, state) {},
      builder: (context, state) {
        return PrimaryButton(
          isLoading: state is ReportLoading,
          onPressed: onPressed,
          text: 'Report',
          bgColor: styles.theme.primary,
          textColor: styles.theme.white,
        );
      },
    );
  }
}
