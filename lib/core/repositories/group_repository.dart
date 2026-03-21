import 'package:dio/dio.dart';
import 'package:waze_kibris/common.dart';
import 'package:waze_kibris/core/models/groups/group_response.dart';
// Auth header is attached by AuthInterceptor when a token exists.

abstract class GroupRepository {
  Future<GetGroupsResponse> getGroups({
    String? filterType,
    double? latitude,
    double? longitude,
    double? radius,
  });
  Future<GroupActionResponse> getGroupById(String groupId);
  Future<GroupActionResponse> createGroup(
    String name,
    String? description,
    String visibility,
    String groupType,
  );
  Future<GroupActionResponse> joinGroupByShortCode(String shortCode);
  Future<GroupActionResponse> leaveGroup(String groupId);
  Future<GetGroupMessagesResponse> getGroupMessages(String groupId);
  Future<SendGroupMessageResponse> sendGroupMessage(
      String groupId, String content, String messageType);
  Future<GetInvitationsResponse> listInvitationsForGroup(String groupId);
  Future<GetInvitationsResponse> listMyInvitations();
  Future<void> createInvitation(String groupId, {String? invitedUserId, String? invitedUserEmail});
  Future<void> acceptInvitation(String invitationId);
  Future<void> declineInvitation(String invitationId);
  Future<void> markGroupRead(String groupId);
}

class GroupRepositoryImpl implements GroupRepository {
  GroupRepositoryImpl({Dio? dio, ILocalStorage? store})
      : _dio = dio ?? getIt<Dio>(),
        _store = store ?? getIt<ILocalStorage>();

  final Dio _dio;
  // Kept for backward compatibility with DI signature; auth headers are set via AuthInterceptor.
  // ignore: unused_field
  final ILocalStorage _store;

  @override
  Future<GetGroupsResponse> getGroups({
    String? filterType,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (filterType != null && filterType.isNotEmpty) {
        queryParameters['filter_type'] = filterType;
      }
      if (latitude != null) {
        queryParameters['lat'] = latitude;
      }
      if (longitude != null) {
        queryParameters['lng'] = longitude;
      }
      if (radius != null) {
        queryParameters['radius'] = radius;
      } else if (filterType == 'near_me') {
        queryParameters['radius'] = 50000;
      }
      final response = await _dio.get<Map<String, dynamic>>(
        '/community',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      );
      return GetGroupsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GroupActionResponse> getGroupById(String groupId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/community/$groupId',
      );
      return GroupActionResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GroupActionResponse> createGroup(
    String name,
    String? description,
    String visibility,
    String groupType,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/community',
        data: {
          'name': name,
          'description': description,
          'visibility': visibility,
          'group_type': groupType,
        },
      );
      return GroupActionResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GroupActionResponse> joinGroupByShortCode(String shortCode) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/community/$shortCode/join',
      );
      return GroupActionResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GroupActionResponse> leaveGroup(String groupId) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/community/$groupId/leave',
      );
      return GroupActionResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GetGroupMessagesResponse> getGroupMessages(String groupId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/community/$groupId/messages',
      );
      return GetGroupMessagesResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<SendGroupMessageResponse> sendGroupMessage(
      String groupId, String content, String messageType) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/community/$groupId/messages',
        data: {
          'content': content,
          'message_type': messageType,
        },
      );
      return SendGroupMessageResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GetInvitationsResponse> listInvitationsForGroup(String groupId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/community/$groupId/invitations',
      );
      return GetInvitationsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<GetInvitationsResponse> listMyInvitations() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/community/users/me/invitations',
      );
      return GetInvitationsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> createInvitation(String groupId,
      {String? invitedUserId, String? invitedUserEmail}) async {
    if ((invitedUserId == null || invitedUserId.isEmpty) &&
        (invitedUserEmail == null || invitedUserEmail.isEmpty)) {
      throw Exception('Provide invited_user_id or invited_user_email');
    }
    try {
      final data = <String, dynamic>{};
      if (invitedUserId != null && invitedUserId.isNotEmpty) {
        data['invited_user_id'] = invitedUserId;
      }
      if (invitedUserEmail != null && invitedUserEmail.isNotEmpty) {
        data['invited_user_email'] = invitedUserEmail;
      }
      await _dio.post<Map<String, dynamic>>(
        '/community/$groupId/invitations',
        data: data,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/community/invitations/$invitationId/accept',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> declineInvitation(String invitationId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/community/invitations/$invitationId/decline',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> markGroupRead(String groupId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/community/$groupId/read',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      final errorData = e.response!.data as Map<String, dynamic>;
      return Exception(errorData['message'] as String? ?? 'An error occurred');
    }
    return Exception('Network error occurred');
  }
}
