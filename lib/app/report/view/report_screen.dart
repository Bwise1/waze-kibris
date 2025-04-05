import 'package:flutter/material.dart';
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
  @override
  void initState() {
// Position? position=await  UserCoordinates.getAndSetUserCoordinate(context);
// context.read<ReportsBloc>().add(GetNearByReports(radius: radius, lat: lat, long: long))
    super.initState();
  }

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
//

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
                        if ((state as GetReportsResponse).data.isEmpty) {
                          return Text(
                            'No current nearby report',
                            style: styles.typography.body,
                          );
                        } else if (state is GetReportSuccess &&
                            (state as GetReportsResponse).data.isEmpty) {
                          return ListView.builder(
                            itemCount: state.data.length,
                            itemBuilder: (context, index) {
                              return Row(
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        '${state.data[index].type.toLowerCase()} Report',
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
                              );
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
                                  final position = await UserCoordinates
                                      .getAndSetUserCoordinate(
                                    context,
                                  );
                                  context.read<ReportsBloc>().add(
                                        ReportsEvent.getNearByReports(
                                          radius: 5,
                                          lat: position!.latitude.toString(),
                                          long: position.longitude.toString(),
                                        ),
                                      );
                                },
                                text: 'Refresh to see new  Reports.',
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
