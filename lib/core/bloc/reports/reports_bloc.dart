import 'dart:async';
import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/bloc/auth/auth_bloc.dart';
import 'package:waze_kibris/core/bloc/auth/auth_event.dart';
import 'package:waze_kibris/core/bloc/reports/report_state.dart';
import 'package:waze_kibris/core/bloc/reports/reports_event.dart';
import 'package:waze_kibris/core/models/reports/report_response.dart';
import 'package:waze_kibris/core/models/reports/ws_report_update.dart';
import 'package:waze_kibris/core/repositories/report_repository.dart';
import 'package:waze_kibris/core/res/store_keys.dart';
import 'package:waze_kibris/core/services/recent_locations_service.dart';
import 'package:waze_kibris/core/services/websocket_service.dart';
import 'package:waze_kibris/core/services/local_storage.dart';
import 'package:waze_kibris/core/utils/report_expiry.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportState> {
  ReportsBloc({
    required ReportRepository reportRepository,
    required this.authBloc,
    required WebSocketService webSocketService,
  })  : _reportRepository = reportRepository,
        _webSocketService = webSocketService,
        _recentLocationsService = RecentLocationsService(getIt<ILocalStorage>()),
        super(const ReportInitial()) {
    on<GetReportByID>(_onRequestReportByID);
    on<GetNearByReports>(_onRequestNearByReport);
    on<VoteOnReport>(_onVoteOnReport);
    on<GetVotesOnReport>(_onGetVotesOnReportRequest);
    on<SaveLocation>(_onSaveLocationRequest);
    on<GetSavedLocations>(_onGetSavedLocationRequest);
    on<GetRecentLocations>(_onGetRecentLocations);
    on<AddRecentLocation>(_onAddRecentLocation);
    on<RemoveRecentLocation>(_onRemoveRecentLocation);
    on<ClearRecentLocations>(_onClearRecentLocations);
    on<SubmitReportRequested>(_onSubmitReportRequested);
    on<ClearExpiredToken>(_onClearExpiredToken);
    on<ReportUpdatedFromWs>(_onReportUpdatedFromWs);
    on<PruneExpiredReports>(_onPruneExpiredReports);

    _pruneExpiredTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!isClosed) add(const PruneExpiredReports());
    });

    _wsSub = _webSocketService.messages.listen((msg) {
      if (msg.type == 'report_update' && msg.content != null) {
        try {
          final json = jsonDecode(msg.content!) as Map<String, dynamic>;
          final update = WsReportUpdate.fromJson(json);
          add(ReportsEvent.reportUpdatedFromWs(update: update));
        } catch (_) {
          // ignore malformed payloads
        }
      }
    });
  }

  final ReportRepository _reportRepository;
  final RecentLocationsService _recentLocationsService;
  final AuthBloc authBloc;
  final WebSocketService _webSocketService;
  Timer? _pruneExpiredTimer;
  StreamSubscription<WsMessage>? _wsSub;
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
          data: filterNonExpiredReports(response.data),
          status: response.status,
          statusCode: response.statusCode,
        ),
      );
    } catch (e) {
      emit(ReportError(message: e.toString()));
    }
  }

  Future<void> _onPruneExpiredReports(
    PruneExpiredReports event,
    Emitter<ReportState> emit,
  ) async {
    final current = state;
    if (current is! GetReportSuccess) return;
    final filtered = filterNonExpiredReports(current.data);
    if (filtered.length == current.data.length) return;
    emit(
      GetReportSuccess(
        message: current.message,
        data: filtered,
        status: current.status,
        statusCode: current.statusCode,
      ),
    );
  }

  //
  Future<void> _onVoteOnReport(
    VoteOnReport event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(const ReportLoading());
      final response = await _reportRepository.voteOnReport(
        event.reportType, // Should be "upvote" or "downvote"
        event.reportID,
      );

      emit(
        VoteReportSuccess(
          message: response.message,
          status: response.status,
          data: response.message, // Backend returns message in data field
        ),
      );
    } catch (e) {
      emit(ReportError(message: e.toString()));
    }
  }

  Future<void> _onReportUpdatedFromWs(
    ReportUpdatedFromWs event,
    Emitter<ReportState> emit,
  ) async {
    final update = event.update;
    final current = state;

    if (current is GetReportSuccess) {
      final reports = [...current.data];
      final index = reports.indexWhere((r) => r.id == update.id);

      if (index >= 0) {
        final r = reports[index];
        reports[index] = ReportData(
          id: r.id,
          userId: r.userId,
          username: r.username,
          type: update.type,
          severity: r.severity,
          active: update.active,
          resolved: update.resolved,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
          expiresAt: r.expiresAt,
          reportSource: r.reportSource,
          reportStatus: r.reportStatus,
          longitude: update.longitude,
          latitude: update.latitude,
          imageUrl: r.imageUrl,
          upvotesCount: update.upvotesCount,
          downvotesCount: update.downvotesCount,
        );
      } else {
        // New report from WebSocket – add to list so it displays on the map
        final now = DateTime.now().toUtc().toIso8601String();
        final expiresAt = DateTime.now().toUtc()
            .add(const Duration(hours: 6))
            .toIso8601String();
        reports.insert(
          0,
          ReportData(
            id: update.id,
            userId: update.userId,
            username: null,
            type: update.type,
            severity: 0,
            active: update.active,
            resolved: update.resolved,
            createdAt: now,
            updatedAt: now,
            expiresAt: expiresAt,
            reportSource: 'user',
            reportStatus: 'pending',
            longitude: update.longitude,
            latitude: update.latitude,
            imageUrl: null,
            upvotesCount: update.upvotesCount,
            downvotesCount: update.downvotesCount,
          ),
        );
      }

      emit(
        GetReportSuccess(
          message: current.message,
          data: filterNonExpiredReports(reports),
          status: current.status,
          statusCode: current.statusCode,
        ),
      );
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
          data: response.votes,
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

  Future<void> _onGetSavedLocationRequest(
    GetSavedLocations event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(const SaveLocationLoading());
      final response = await _reportRepository.getSavedLocations();
      debugPrint("${response.data.toString()}=====================");
      if (response.statusCode == 404) {
        emit(const ReportError(message: 'no saved location available.'));

        return;
      }
      _savedRetryAttempt = 0;
      emit(
        GetSavedLocationsSuccess(
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
      // A dead network at launch (field log: 'Failed host lookup') left the
      // Saved section empty for the whole session — the sheet only asks
      // once, in initState. Retry with backoff; groups recovered seconds
      // later in the same log, so the network usually comes right back.
      if (e.toString().contains('Network error occurred') &&
          _savedRetryAttempt < _savedRetryDelays.length) {
        final delay = _savedRetryDelays[_savedRetryAttempt++];
        _savedRetryTimer?.cancel();
        _savedRetryTimer = Timer(
          Duration(seconds: delay),
          () => add(ReportsEvent.getSavedLocations()),
        );
      }
    }
  }

  Timer? _savedRetryTimer;
  int _savedRetryAttempt = 0;
  static const _savedRetryDelays = [3, 8, 20, 45]; // seconds

  Future<void> _onSaveLocationRequest(
    SaveLocation event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(const SaveLocationLoading());
      final response = await _reportRepository.saveLocation(
          event.locationName, event.address, event.lat, event.lng, event.placeId);
      if (response.statusCode == 404) {
        emit(const ReportError(message: 'Could not save location'));
        return;
      }

      // add(AuthEvent.getProfileRequested());
      add(ReportsEvent.getSavedLocations());

      ///successfully save location
      emit(
        SaveLocationSuccess(
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
        imageFile: event.imageFile,
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

        add(
          ReportsEvent.getNearByReports(
              radius: 5000,
              lat: event.latitude.toString(),
              long: event.longitude.toString()),
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

  Future<void> _onGetRecentLocations(
    GetRecentLocations event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(const RecentLocationsLoading());
      final recentLocations = await _recentLocationsService.getRecentLocations();
      emit(GetRecentLocationsSuccess(data: recentLocations));
    } catch (e) {
      emit(ReportError(message: e.toString()));
    }
  }

  Future<void> _onAddRecentLocation(
    AddRecentLocation event,
    Emitter<ReportState> emit,
  ) async {
    try {
      debugPrint('🔥 BLoC: Adding recent location ${event.location.name}');
      await _recentLocationsService.addRecentLocation(event.location);
      emit(const AddRecentLocationSuccess());
      
      // Refresh the recent locations list
      final recentLocations = await _recentLocationsService.getRecentLocations();
      debugPrint('🔥 BLoC: Retrieved ${recentLocations.length} recent locations');
      emit(GetRecentLocationsSuccess(data: recentLocations));
    } catch (e) {
      debugPrint('❌ BLoC: Error adding recent location: $e');
      emit(ReportError(message: e.toString()));
    }
  }

  Future<void> _onRemoveRecentLocation(
    RemoveRecentLocation event,
    Emitter<ReportState> emit,
  ) async {
    try {
      await _recentLocationsService.removeRecentLocation(event.placeId);
      emit(const RemoveRecentLocationSuccess());
      
      // Refresh the recent locations list
      final recentLocations = await _recentLocationsService.getRecentLocations();
      emit(GetRecentLocationsSuccess(data: recentLocations));
    } catch (e) {
      emit(ReportError(message: e.toString()));
    }
  }

  Future<void> _onClearRecentLocations(
    ClearRecentLocations event,
    Emitter<ReportState> emit,
  ) async {
    try {
      await _recentLocationsService.clearRecentLocations();
      emit(const ClearRecentLocationsSuccess());
      emit(const GetRecentLocationsSuccess(data: []));
    } catch (e) {
      emit(ReportError(message: e.toString()));
    }
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

  @override
  Future<void> close() {
    _pruneExpiredTimer?.cancel();
    // Both of these outlive close() otherwise: the WS subscription keeps
    // calling add() on a closed bloc (StateError on the next report frame
    // after a hot-restart/provider rebuild), and the saved-locations retry
    // timer fires into the dead bloc up to 45s later.
    _wsSub?.cancel();
    _savedRetryTimer?.cancel();
    return super.close();
  }
}

enum ReportType {
  traffic,
  police,
  accident,
  alternateRoute,
  photoSharing,
  chatPage,
}
