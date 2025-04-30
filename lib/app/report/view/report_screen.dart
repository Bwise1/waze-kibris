import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/utils/user_coordinates.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController _idFieldController = TextEditingController();
  ScreenshotController screenshotController = ScreenshotController();

  double startRangeVal = 0;
  double endRangeVal = 50;
  @override
  initState() {
    super.initState();
    print('hello');
    getNearReport(context);
  }

  Future<void> getNearReport(BuildContext context) async {
    final position = await UserCoordinates.getAndSetUserCoordinate(
      context,
    );
    if (context.mounted) {
      context.read<ReportsBloc>().add(
            ReportsEvent.getNearByReports(
              radius: endRangeVal.toInt(),
              lat: position!.latitude.toString(),
              long: position.longitude.toString(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Gap(45 * styles.scale),
                SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          hintText: 'Find report type with ID',
                          controller: _idFieldController,
                          onChanged: (v) {
                            setState(() {});
                          },
                          prefix: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 45,
                                width: 45,
                                child: AppIcon(
                                  Assets.icons.coordinate,
                                  color: styles.theme.grey,
                                  size: 18,
                                ),
                              ),
                              Text(
                                '|',
                                style: styles.typography.h4
                                    .textColor(styles.theme.ash),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Gap(16 * styles.scale),
                      CustomClickableText(
                        onTap: () {
                          context.read<ReportsBloc>().add(
                                ReportsEvent.getReportByID(
                                  reportID: _idFieldController.text,
                                ),
                              );
                        },
                        padding: EdgeInsets.all(10 * styles.scale),
                        color: styles.theme.divider,
                        text: _idFieldController.text.isNotEmpty
                            ? 'Find'
                            : 'Paste ID', //
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final imageBytes = await screenshotController.captureFromWidget(
                IconImageMakerWidget(
                  iconObject: Assets.icons.police.image(),
                ),
              );
              print(imageBytes);
            },
            child: IconImageMakerWidget(
              iconObject: Assets.icons.policeCar.image(),
            ),
          ),
          BlocConsumer<ReportsBloc, ReportState>(
            listener: (context, state) {
              if (state is GetReportSuccess && state.data.isEmpty) {
                RSnackBar.error(
                  'No current report close to you at the moment.',
                );
              } else if (state is GetReportSuccess && state.data.isNotEmpty) {
                RSnackBar.error(
                  '${state.data.length}',
                );
              }
            },
            builder: (context, state) {
              if (state is ReportInitial) {
                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomClickableText(
                        text: 'No current nearby reports',
                        style:
                            styles.typography.body.textColor(styles.theme.grey),
                        color: Colors.white,
                      ),
                      const Icon(
                        size: 40,
                        Icons.refresh_rounded,
                      ),
                    ],
                  ).rippleClick(
                    () async {
                      final position =
                          await UserCoordinates.getAndSetUserCoordinate(
                        context,
                      );
                      if (context.mounted) {
                        context.read<ReportsBloc>().add(
                              ReportsEvent.getNearByReports(
                                radius: 5,
                                lat: position!.latitude.toString(),
                                long: position.longitude.toString(),
                              ),
                            );
                      } //
                    },
                  ),
                );
              } else if (state is GetReportSuccess && state.data.isNotEmpty) {
                return Expanded(
                  child: ListView.builder(
                    itemCount: state.data.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${state.data[index].type.toLowerCase()} '
                                  'Report',
                                  style: styles.typography.body,
                                  // .textColor(styles.theme.text),
                                ),
                                Gap(4 * styles.scale),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'ID:',
                                      style: styles.typography.t3
                                          .textColor(styles.theme.caption),
                                    ),
                                    Text(
                                      ' ${state.data[index].latitude}',
                                      style: styles.typography.t1,
                                      // .textColor(styles.theme.divider),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                            ),
                          ],
                        ),
                      ).clickable(() {
                        //get the numbers of votes on a certain report
                        context.read<ReportsBloc>().add(
                              ReportsEvent.getVotesOnReport(
                                reportID: state.data[index].id,
                              ),
                            );

                        //open the bottom sheet for the detail screen
                        CustomDialogRoutes.showBottomSheet<bool>(
                          context,
                          ReportDetailScreen(report: state.data[index]),
                        );
                      });
                    },
                  ),
                );
              }
              // else if (state is SubmitReportSuccess) {
              //   return Padding(
              //     padding: const EdgeInsets.symmetric(horizontal: 20),
              //     child: Row(
              //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //       children: [
              //         Column(
              //           crossAxisAlignment: CrossAxisAlignment.start,
              //           children: [
              //             Text(
              //                 '${state.data.type.toLowerCase()} '
              //                 'Report',
              //                 style: styles.typography.body
              //                 // .textColor(styles.theme.text),
              //                 ),
              //             Gap(4 * styles.scale),
              //             Wrap(
              //               crossAxisAlignment: WrapCrossAlignment.center,
              //               children: [
              //                 Text(
              //                   'ID:',
              //                   style: styles.typography.t3
              //                       .textColor(styles.theme.caption),
              //                 ),
              //                 Text(' ${state.data.latitude}',
              //                     style: styles.typography.t1
              //                     // .textColor(styles.theme.divider),
              //                     ),
              //               ],
              //             ),
              //           ],
              //         ),
              //         const Icon(
              //           Icons.arrow_forward_ios_rounded,
              //         ),
              //       ],
              //     ).clickable(() {
              //       //get the numbers of votes on a certain report
              //       context.read<ReportsBloc>().add(
              //             ReportsEvent.getVotesOnReport(
              //               reportID: state.data.id,
              //             ),
              //           );
              //
              //       //open the bottom sheet for the detail screen
              //       CustomDialogRoutes.showBottomSheet<bool>(
              //         context,
              //         ReportDetailScreen(report: state.data),
              //       );
              //     }),
              //   );
              // }
              else if (state is ReportLoading) {
                return Expanded(
                  child: Center(
                    child: SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(
                        color: styles.theme.primary,
                      ),
                    ),
                  ),
                );
              } else {
                return Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomClickableText(
                          text: 'Simplify your search to certain distance',
                          style:
                              styles.typography.h5.textColor(styles.theme.body),
                        ),
                        Gap(8 * styles.scale),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            RangeSlider(
                              max: 100,
                              values: RangeValues(startRangeVal, endRangeVal),
                              onChanged: (val) {
                                setState(() {
                                  endRangeVal = val.end;
                                  // startRangeVal = val.start;
                                });
                              },
                              onChangeEnd: (endVal) {
                                setState(() {
                                  endRangeVal = endVal.end;
                                  // startRangeVal = endVal.start;
                                });
                              },
                              onChangeStart: (endVal) {
                                setState(() {
                                  endRangeVal = endVal.end;
                                  startRangeVal = endVal.start;
                                });
                              },
                              activeColor: Colors.red,
                            ),
                            Positioned(
                              left: 20,
                              bottom: -30,
                              child: Row(
                                children: [
                                  Text(
                                    'Radius searched: ',
                                    style: styles.typography.hairline,
                                  ),
                                  Text(
                                    '${endRangeVal.toInt()} (meters)',
                                    style: styles.typography.h5,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Gap(53 * styles.scale),
                        TextButton(
                          onPressed: () async {
                            if (state is GetVotesOnReportSuccess) {
                              RSnackBar.error('Hey${state.data.length}')
                                  .show(context);
                            } else {
                              RSnackBar.error('Hey Nothing here').show(context);
                            }
                            final position =
                                await UserCoordinates.getAndSetUserCoordinate(
                              context,
                            );
                            if (context.mounted) {
                              // print(
                              //   "${position!.latitude.toString()}"
                              //   "${position.longitude.toString()}",
                              // );
                              // RSnackBar.error(
                              //         "${position!.latitude.toString()} ${position.longitude.toString()}")
                              //     .show(context);
                              context.read<ReportsBloc>().add(
                                    ReportsEvent.getNearByReports(
                                      radius: endRangeVal.toInt(),
                                      lat: position!.latitude.toString(),
                                      long: position.longitude.toString(),
                                    ),
                                  );
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: styles.theme.divider,
                          ),
                          child: const Icon(
                            size: 35,
                            Icons.search_rounded,
                            // color: styles.theme.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({required this.report, super.key});

  final ReportData report;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(styles.insets.md),
      child: BlocConsumer<ReportsBloc, ReportState>(
        listener: (context, state) {
          if (state is VoteReportSuccess) {
            RSnackBar.success(state.message).show(context);
          }
        },
        builder: (context, state) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${report.type} Report ',
                style: styles.typography.f.size(20).bold,
              ),
              Container(
                height: 68,
                width: 68,
                decoration: BoxDecoration(
                  color: styles.theme.grey.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Map Widget comes here',
                  style: styles.typography.f.size(20).bold,
                ),
              ),
              Gap(styles.insets.xl),
              Text(
                'Reported by a ${report.reportSource} ',
                style: styles.typography.f.size(20).bold,
              ),
              Gap(styles.insets.xl),
              Text(
                '${(state is GetVotesOnReportSuccess) ? state.data.length : ''}'
                'voted on this report.',
                style: styles.typography.f.size(20).bold,
              ).clickable(() {
                context.go(ScreenPaths.reportVotes);
              }),
              Gap(styles.insets.lg),
              PrimaryButton(
                isLoading: state is ReportLoading,
                onPressed: () {
                  context.read<ReportsBloc>().add(
                        ReportsEvent.voteOnReport(
                          reportID: report.id,
                          reportType: ReportVoteType.upvote.name.toUpperCase(),
                        ),
                      );
                },
                text: 'Vote on report',
                bgColor: styles.theme.secondary,
                textColor: styles.theme.primary,
              ),
              Gap(styles.insets.md),
            ],
          );
        },
      ),
    );
  }
}

enum ReportVoteType { upvote }

class IconImageMakerWidget extends StatelessWidget {
  const IconImageMakerWidget({required this.iconObject, super.key});
  final Widget iconObject;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 45,
            color: styles.theme.border, //
          ),
          Positioned(
            top: 3,
            child: SizedBox(
              height: 30,
              width: 30,
              child: iconObject,
            ),
          ),
        ],
      ),
    );
  }
}
