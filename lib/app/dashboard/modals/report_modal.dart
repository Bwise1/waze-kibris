import 'package:flutter/material.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
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
      'icon': Assets.icons.police.image(),
      'isNewPage': false,
      'page': const ReportPoliceEventModal(),
    },
    {
      'name': 'Traffic',
      'type': ReportType.traffic.name,
      'icon': Assets.icons.warningCars.image(),
      'isNewPage': false,
      'page': const ReportPoliceEventModal(),
    },
    {
      'name': 'Accident',
      'type': ReportType.accident.name,
      'icon': Assets.icons.accident.image(),
      'isNewPage': false,
      'page': const ReportPoliceEventModal(),
    },
    {
      'name': 'Alternate Route',
      'type': ReportType.alternateRoute.name,
      'icon': Assets.icons.arrow.image(),
      'isNewPage': true,
      'page': const ReportPoliceEventModal(),
    },
    {
      'name': 'Photo Sharing',
      'type': ReportType.alternateRoute.name,
      'icon': Assets.icons.sendingIll.image(),
      'isNewPage': true,
      'page': const ReportPoliceEventModal(),
    },
    {
      'name': 'Chat',
      'type': ReportType.photoSharing.name,
      'icon': Assets.icons.chat.image(),
      'isNewPage': true,
      'page': const ReportPoliceEventModal(),
    },
  ];
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(styles.insets.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 6,
            width: 68,
            decoration: BoxDecoration(
              color: styles.theme.grey.withValues(alpha: .3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Gap(styles.insets.sm),
          Text('What do you see', style: styles.typography.f.size(20).bold),
          Text(
            'Aid others by telling us what you see',
            style: styles.typography.t3.textColor(styles.theme.caption),
          ),
          GridView.builder(
            itemCount: reports.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 19,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  if (reports[index]['isNewPage'] as bool) {
                    /// this mean we are navigating to a different new page
                    ///
                    ///
                    ///
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
                        borderRadius: BorderRadius.circular(styles.corners.md),
                        boxShadow: styles.shadows.md,
                      ),
                      padding: EdgeInsets.all(styles.insets.md),
                      child: reports[index]['icon'] as Widget,
                    ),
                    Gap(styles.insets.xs),
                    Text(
                      reports[index]['name'] as String,
                      style: styles.typography.overline.bold,
                    ),
                  ],
                ),
              );
            },
          ),
          Gap(styles.insets.sm),
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
    // context.read<AuthBloc>().add(
    //       AuthEvent.getUserCoordinateRequested(context: context),
    //     );
  }

  int? _selectedIndex;
  @override
  Widget build(BuildContext context) {
    final reports = <Map<String, dynamic>>[
      {
        'type': ReportType.police.name,
        'subType': 'police',
        'icon': Assets.icons.police.image(),
      },
      {
        'type': ReportType.police.name,
        'subType': 'patrol',
        'icon': Assets.icons.policeCar.image(),
      },
      {
        'type': ReportType.police.name,
        'subType': 'otherLane',
        'icon': Assets.icons.accident.image(),
      }
    ];
    return Padding(
      padding: EdgeInsets.all(styles.insets.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 6,
            width: 68,
            decoration: BoxDecoration(
              color: styles.theme.grey.withValues(alpha: .3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Gap(styles.insets.sm),
          Text('Report Police', style: styles.typography.f.size(20).bold),
          Gap(styles.insets.sm),
          GridView.builder(
            itemCount: reports.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 19,
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
                                    BorderRadius.circular(styles.corners.md),
                                boxShadow: styles.shadows.md,
                              ),
                              padding: EdgeInsets.all(styles.insets.md),
                              child: reports[index]['icon'] as Widget,
                            ),
                            Gap(styles.insets.xs),
                            Text(
                              reports[index]['type'] as String,
                              style: styles.typography.overline.bold,
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
                  Gap(styles.insets.sm),
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
                            if (authState is UserCoordinate) {
                              reportContext.read<ReportsBloc>().add(
                                    ReportsEvent.submitReportRequested(
                                      longitude: authState.longitude,
                                      latitude: authState.longitude,
                                      type: reports[_selectedIndex ?? 0]['type']
                                          .toString(),
                                    ),
                                  );
                            }
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
