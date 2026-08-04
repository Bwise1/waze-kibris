import 'package:flutter/material.dart';
import 'package:waze_kibris/app/report/view/report_screen.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_bloc.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
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
                        if (state is GetVotesOnReportSuccess) {
                          final votes = state.data;
                          if (votes.isEmpty) {
                            return Text(
                              'No votes for this report.',
                              style: styles.typography.body,
                            );
                          }
                          return ListView.builder(
                            itemCount: votes.length,
                            itemBuilder: (context, index) {
                              final v = votes[index];
                              return ListTile(
                                title: Text(
                                  v.voteType,
                                  style: styles.typography.body.bold,
                                ),
                                subtitle: Text(
                                  'User: ${v.userId}\n${v.createdAt}',
                                  style: styles.typography.caption,
                                ),
                              );
                            },
                          );
                        }
                        if (state is GetReportSuccess &&
                            state.data.isNotEmpty) {
                          return ListView.builder(
                            itemCount: state.data.length,
                            itemBuilder: (context, index) {
                              final r = state.data[index];
                              return Row(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${r.type.toLowerCase()} report',
                                        style: styles.typography.h3
                                            .textColor(styles.theme.text),
                                      ),
                                      Gap(16 * styles.scale),
                                      Text(
                                        'Id: ${r.id}',
                                        style: styles.typography.h3
                                            .textColor(styles.theme.text),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_forward_ios_rounded),
                                ],
                              ).clickable(() {
                                context.read<ReportsBloc>().add(
                                      ReportsEvent.getVotesOnReport(
                                        reportID: r.id,
                                      ),
                                    );
                                CustomDialogRoutes.showBottomSheet<bool>(
                                  context,
                                  ReportDetailScreen(report: r),
                                );
                              });
                            },
                          );
                        }
                        if (state is ReportLoading) {
                          return CircularProgressIndicator(
                            color: styles.theme.primary,
                          );
                        }
                        return Column(
                          children: [
                            CustomClickableText(
                              onTap: () {},
                              text: 'Open a report to load votes.',
                              style: styles.typography.h3,
                            ),
                            Gap(16 * styles.scale),
                            const SlideIndicator(),
                          ],
                        );
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
