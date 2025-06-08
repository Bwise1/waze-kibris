import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:waze_kibris/app/dashboard/view/main_dashboard.dart';
import 'package:waze_kibris/core/models/places/places_response.dart'; // For AutocompleteSuggestion

class PlacesService {
  static const String backendBaseUrl = 'https://waze-api.benjys.me';
  final Dio _dio = Dio();

  Future<List<AutocompleteSuggestion>> fetchSuggestions(String query) async {
    try {
      final response = await _dio.get(
        '$backendBaseUrl/places/autocomplete',
        queryParameters: {'text': query},
        options: Options(headers: {
          'Content-Type': 'application/json',
          'X-Request-Source': 'postman',
        }),
      );

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;

        // Debug: Print the actual response to understand the structure
        print('Autocomplete response data: $responseData');
        print('Response type: ${responseData.runtimeType}');

        if (responseData is Map<String, dynamic>) {
          // Handle wrapped response (your backend format)
          if (responseData.containsKey('data') &&
              responseData.containsKey('status')) {
            final dynamic data = responseData['data']; // Don't cast to Map yet

            if (data is List) {
              // Handle direct list response (your actual format)
              return data.map<AutocompleteSuggestion>((item) {
                if (item is Map<String, dynamic>) {
                  return AutocompleteSuggestion(
                    id: item['gid']?.toString() ?? '',
                    description: item['name']?.toString() ?? '',
                    name: item['name']?.toString(),
                    location: item['coarse_location']?.toString(),
                  );
                } else {
                  throw Exception('Invalid item format in list response');
                }
              }).toList();
            } else if (data is Map<String, dynamic>) {
              // Handle GeoJSON FeatureCollection (if your backend sometimes returns this)
              if (data['type'] == 'FeatureCollection' &&
                  data.containsKey('features')) {
                final List features = data['features'] as List;

                return features.map<AutocompleteSuggestion>((feature) {
                  final properties =
                      feature['properties'] as Map<String, dynamic>;

                  return AutocompleteSuggestion(
                    id: properties['gid']?.toString() ?? '',
                    description: properties['name']?.toString() ?? '',
                    name: properties['name']?.toString(),
                    location: properties['coarse_location']?.toString(),
                  );
                }).toList();
              } else {
                throw Exception(
                    'Unknown Map format in data field: ${data.keys}');
              }
            } else {
              throw Exception(
                  'Data field is neither List nor Map: ${data.runtimeType}');
            }
          }

          throw Exception('Unknown Map response format: ${responseData.keys}');
        } else if (responseData is List) {
          // Handle direct list response (fallback)
          return responseData.map<AutocompleteSuggestion>((item) {
            if (item is Map<String, dynamic>) {
              return AutocompleteSuggestion(
                id: item['gid']?.toString() ?? item['id']?.toString() ?? '',
                description: item['name']?.toString() ??
                    item['description']?.toString() ??
                    '',
                name: item['name']?.toString(),
                location: item['coarse_location']?.toString() ??
                    item['location']?.toString(),
              );
            } else {
              throw Exception('Invalid item format in list response');
            }
          }).toList();
        } else {
          throw Exception(
              'Response data is neither List nor Map, it is: ${responseData.runtimeType}');
        }
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('Dio error: ${e.response?.data}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint('Parsing error: $e');
      throw Exception('Parsing error: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchPlaceDetails(String gid) async {
    try {
      final response = await _dio.get(
        '$backendBaseUrl/places/placedetails',
        queryParameters: {'gid': gid},
        options: Options(headers: {
          'Content-Type': 'application/json',
          'X-Request-Source': 'flutter-app',
        }),
      );

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;

        if (responseData is Map<String, dynamic>) {
          // Handle your backend's wrapped response
          if (responseData.containsKey('data') &&
              responseData.containsKey('status')) {
            final data = responseData['data'] as Map<String, dynamic>;

            debugPrint('________________+++++++++++$data');

            return {
              'name': data['name']?.toString() ?? '',
              'address': data['address']?.toString() ?? '',
              'coordinates': LatLng(
                data['latitude'] as double ?? 0.0,
                data['longitude'] as double ?? 0.0,
              ),
            };
          }
        }

        throw Exception('Invalid place details response format');
      } else {
        throw Exception('Place details API Error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('Place details Dio error: ${e.response?.data}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint('Place details parsing error: $e');
      throw Exception('Parsing error: $e');
    }
  }

  /// Accepts origin and destination, returns a List<Map<String, dynamic>> of routes
  Future<List<Map<String, dynamic>>> fetchRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final String backendUrl = '$backendBaseUrl/route';
    final payload = {
      'locations': [
        {
          'lat': origin.latitude,
          'lon': origin.longitude,
        },
        {
          'lat': destination.latitude,
          'lon': destination.longitude,
        },
      ],
      // 'costing': 'auto',
      // 'units': 'kilometers',
      // 'directions_options': {'narrative': true},
    };

    try {
      final response = await Dio().post(
        backendUrl,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Request-Source': 'postman',
          },
        ),
      );

      if (response.statusCode == 200) {
        final routeData = response.data as Map<String, dynamic>;
        final data = routeData['data'];
        final mainRoute = data['trip'] as Map<String, dynamic>;
        final alternatesRaw = data['alternates'];
        final alternates = (alternatesRaw is List)
            ? alternatesRaw
                .map<Map<String, dynamic>>((e) => e as Map<String, dynamic>)
                .toList()
            : <Map<String, dynamic>>[];
        return [mainRoute, ...alternates];
      } else {
        throw Exception('Failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(':::::::::::Error fetching route: $e');
      rethrow;
    }
  }
}
