import 'dart:developer';

import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/repositories/report_repository.dart';
import 'package:waze_kibris/core/res/store_keys.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportState> {
  ReportsBloc({
    required ReportRepository reportRepository,
    required this.authBloc,
  })  : _reportRepository = reportRepository,
        // _localStorage = localStorage ?? getIt<ILocalStorage>(),
        super(const ReportInitial()) {
    on<GetReportByID>(_onRequestReportByID);
    on<GetNearByReports>(_onRequestNearByReport);
    on<VoteOnReport>(_onVoteOnReport);
    on<GetVotesOnReport>(_onGetVotesOnReportRequest);
    on<SubmitReportRequested>(_onSubmitReportRequested);
    on<ClearExpiredToken>(_onClearExpiredToken);
  }

  final ReportRepository _reportRepository;
  final AuthBloc authBloc;
  // final ILocalStorage _localStorage;
  Future<void> _onRequestReportByID(
    GetReportByID event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(const ReportLoading());
      final response = await _reportRepository.getReportById(
        event.reportID.toString(),
      );
      if (response.statusCode == 404) {
        emit(const ReportError(message: 'This Report could be not found'));
        return;
      }
      if (response.statusCode == 403) {
        emit(const ReportError(message: 'Report have been deleted'));
        return;
      }
      emit(
        SubmitReportSuccess(
          data: response.data,
          message: response.message,
          status: response.status,
        ),
      );
    } catch (e) {
      if (e.toString() == 'Exception: token-expired') {
        authBloc.add(
          AuthEvent.refreshTokenRequested(
            onRefreshToken: () {},
          ),
        );
      }
      emit(ReportError(message: e.toString()));
    }
  }

  Future<void> _onRequestNearByReport(
    GetNearByReports event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(const ReportLoading());
      final response = await _reportRepository.getNearByReport(
        event.lat,
        event.long,
        event.radius,
      );
      if (response.statusCode == 409) {
        emit(
          const ReportError(
            message: 'Error has occurred fetching nearby reports',
          ),
        );
        return;
      }
      emit(
        GetReportSuccess(
          message: response.message,
          data: response.data,
          status: response.status,
          statusCode: response.statusCode,
        ),
      );
    } catch (e) {
      if (e.toString() == 'Exception: token-expired') {
        authBloc.add(
          AuthEvent.refreshTokenRequested(
            onRefreshToken: () {},
          ),
        );
      }
      emit(ReportError(message: e.toString()));
    }
  }

  //
  Future<void> _onVoteOnReport(
    VoteOnReport event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(const ReportLoading());
      // final response = await _reportRepository.voteOnReport(
      //   event.reportType,
      //   event.reportID,
      // );
      // emit(
      //   AuthSuccess(
      //     message: response.message,
      //     user: response.data?.user,
      //     token: response.data?.token,
      //   ),
      // );
    } catch (e) {
      emit(ReportError(message: e.toString()));
    }
  }

  //
  Future<void> _onGetVotesOnReportRequest(
    GetVotesOnReport event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(const ReportLoading());
      final response = await _reportRepository.getVotesOnReport(event.reportID);
      if (response.statusCode == 404) {
        emit(const ReportError(message: 'Reports not available.'));
        return;
      }
      emit(
        GetVotesOnReportSuccess(
          message: response.message,
          statusCode: response.statusCode,
          status: response.status,
          data: response.data,
        ),
      );
    } catch (e) {
      emit(ReportError(message: e.toString()));
      if (e.toString() == 'Exception: token-expired') {
        authBloc.add(
          AuthEvent.refreshTokenRequested(
            onRefreshToken: () {},
          ),
        );
      }
    }
  }

//
  //
  Future<void> _onSubmitReportRequested(
    SubmitReportRequested event,
    Emitter<ReportState> emit,
  ) async {
    try {
      // log('message emit ${event.longitude} and ${event.latitude}');
      emit(const ReportLoading());
      final response = await _reportRepository.submitReport(
        event.latitude,
        event.longitude,
        event.type,
      ); //

      log(response.toString());
      if (response.statusCode == 401) {
        emit(
          const ReportError(
            message: 'token expired ',
          ),
        );
        return;
      }
      if (response.statusCode == 404) {
        emit(
          const ReportError(
            message: 'An error occurred while submitting your report. ',
          ),
        );
        return;
      } else {
        emit(
          SubmitReportSuccess(
            data: response.data,
            message: response.message,
            status: response.status,
          ),
        );
      }
    } catch (e) {
      emit(ReportError(message: e.toString()));

      if (e.toString().trim() == 'Exception: token-expired') {
        authBloc.add(
          AuthEvent.refreshTokenRequested(onRefreshToken: () {}),
        );
      }
    }
  }

  Future<void> _onClearExpiredToken(
    ClearExpiredToken event,
    Emitter<ReportState> emit,
  ) async {
    await getIt<ILocalStorage>().delete(StoreKeys.wazeToken);
  }

  // Future<void> _onGetProfileRequested(
  //   GetProfileRequested event,
  //   Emitter<AuthState> emit,
  // ) async {
  //   try {
  //     if (isEmptyOrNull(
  //       getIt<ILocalStorage>().get<String>(StoreKeys.wazeToken),
  //     )) {
  //       // don't call the get profile function if theres no token in the local
  //       // store
  //       return;
  //     }
  //
  //     emit(const AuthLoading());
  //     final response = await _authRepository.getProfile();
  //     emit(
  //       AuthSuccess(
  //         message: response.message,
  //         user: response.data?.user,
  //         token: response.data?.token,
  //       ),
  //     );
  //   } catch (e) {
  //     emit(AuthError(message: e.toString()));
  //   }
  // }
  //
  // void _onLogoutRequested(
  //   LogoutRequested event,
  //   Emitter<AuthState> emit,
  // ) {
  //   emit(const LoggedOut());
  // }
}

enum ReportType {
  traffic,
  police,
  accident,
  alternateRoute,
  photoSharing,
  chatPage,
}
