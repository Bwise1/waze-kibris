import 'package:flutter/material.dart';
import 'package:waze_kibris/app/report/view/report_screen.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';

class ReportVotesScreen extends StatelessWidget {
  const ReportVotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: styles.insets.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Gap(16 * styles.scale),
                  Text(
                    'Reports that are close to you.',
                    style: styles.typography.h3.textColor(styles.theme.text),
                  ),

                  Gap(16 * styles.scale),
                  // CustomClickableText(
                  //   onTap: () {},
                  //   text: 'Navigation',
                  // ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      color: styles.theme.secondary,
                      thickness: 1,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          hintText: 'Find a specific report, type in its ID',
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
                      Expanded(
                        child: CustomClickableText(onTap: () {}, text: 'ID'),
                      ),
                    ],
                  ),

                  Expanded(
                    child: BlocConsumer<ReportsBloc, ReportState>(
                      listener: (context, state) {},
                      builder: (context, state) {
                        if ((state as GetVotesOnReportSuccess).data.isEmpty) {
                          return Text(
                            'No current nearby report',
                            style: styles.typography.body,
                          );
                        } else if (state is GetReportSuccess &&
                            (state as GetReportsResponse).data.isNotEmpty) {
                          return ListView.builder(
                            itemCount: state.data.length,
                            itemBuilder: (context, index) {
                              return Row(
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        '${state.data[index].type.toLowerCase()}'
                                        'Report',
                                        style: styles.typography.h3
                                            .textColor(styles.theme.text),
                                      ),
                                      Gap(16 * styles.scale),
                                      Text(
                                        'Id: ${state.data[index].id}',
                                        style: styles.typography.h3
                                            .textColor(styles.theme.text),
                                      ),
                                    ],
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                  ),
                                ],
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
                          );
                        } else if (state is ReportLoading) {
                          return CircularProgressIndicator(
                            color: styles.theme.primary,
                          );
                        } else {
                          return Column(
                            children: [
                              CustomClickableText(
                                onTap: () async {
                                  if (context.mounted) {
                                    // context.read<ReportsBloc>().add(
                                    //       ReportsEvent.getNearByReports(
                                    //         radius: 5,
                                    //         lat: position!.latitude.toString(),
                                    //         long: position.longitude.toString(),
                                    //       ),
                                    //     );
                                  }
                                },
                                text: 'Refresh to see new votes.',
                                style: styles.typography.h3,
                              ),
                              Gap(16 * styles.scale),
                              const SlideIndicator(),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
