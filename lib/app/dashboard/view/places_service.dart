import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    show Point, Position;

import 'package:waze_kibris/app/dashboard/view/search_widget.dart';
import 'package:waze_kibris/core/models/directions/google_directions_response.dart';
import 'package:waze_kibris/core/models/directions/mapbox_directions_response.dart';
import 'package:waze_kibris/core/models/places/places_response.dart'; // For AutocompleteSuggestion
import 'package:waze_kibris/core/res/store_keys.dart';
import 'package:waze_kibris/core/services/local_storage.dart';

class PlacesService {
  static const String backendBaseUrl = 'https://waze-api.benjys.me';
  final Dio _dio = Dio();
  final ILocalStorage _store;

  PlacesService(this._store);

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_store.get<String>(StoreKeys.wazeToken)}',
        'X-Request-Source': 'flutter-app',
      };

  Future<List<AutocompleteSuggestion>> fetchSuggestions(String query) async {
    try {
      final response = await _dio.get(
        '$backendBaseUrl/places/autocomplete',
        queryParameters: {'text': query},
        options: Options(headers: _authHeaders),
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
        options: Options(headers: _authHeaders),
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
      final response = await _dio.post(
        backendUrl,
        data: payload,
        options: Options(headers: _authHeaders),
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

  Future<List<SearchSuggestion>> fetchGoogleAutocomplete(
    String query, {
    double? lat,
    double? lon,
    int? radius,
  }) async {
    final params = {'text': query};
    if (lat != null && lon != null) {
      params['lat'] = lat.toString();
      params['lon'] = lon.toString();
    }
    if (radius != null) {
      params['radius'] = radius.toString();
    }

    try {
      final response = await _dio.get(
        '$backendBaseUrl/places/googleautocomplete',
        queryParameters: params,
        options: Options(headers: _authHeaders),
      );

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;
        List<dynamic>? predictions;

        // Handle the nested structure: data.predictions
        if (responseData is Map<String, dynamic>) {
          // First check if there's a 'data' wrapper
          if (responseData['data'] is Map<String, dynamic>) {
            final dataMap = responseData['data'] as Map<String, dynamic>;
            if (dataMap['predictions'] is List) {
              predictions = dataMap['predictions'] as List<dynamic>;
            }
          }
          // Fallback: check for direct 'predictions' key
          else if (responseData['predictions'] is List) {
            predictions = responseData['predictions'] as List<dynamic>;
          }
          // Another fallback: check if 'data' is directly a list
          else if (responseData['data'] is List) {
            predictions = responseData['data'] as List<dynamic>;
          }
        }
        // Handle case where response is directly a list
        else if (responseData is List) {
          predictions = responseData;
        }

        if (predictions != null && predictions.isNotEmpty) {
          return predictions.map<SearchSuggestion>((item) {
            if (item is! Map<String, dynamic>) {
              throw Exception('Invalid prediction item format');
            }

            final formatting =
                item['structured_formatting'] as Map<String, dynamic>? ?? {};
            return SearchSuggestion(
              placeId: item['place_id']?.toString() ?? '',
              mainText: formatting['main_text']?.toString() ?? '',
              secondaryText: formatting['secondary_text']?.toString() ?? '',
              distanceMeters:
                  _parseDistanceMeters(item['distance_meters']).toDouble(),
            );
          }).toList();
        } else {
          // Return empty list instead of throwing exception for no results
          return <SearchSuggestion>[];
        }
      } else {
        throw Exception(
            'API Error: ${response.statusCode} - ${response.statusMessage}');
      }
    } on DioException catch (e) {
      debugPrint('Dio error: ${e.response?.data}');
      if (e.response?.statusCode == 404) {
        throw Exception('Autocomplete service not found');
      } else if (e.response?.statusCode == 500) {
        throw Exception('Server error occurred');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint('Parsing error: $e');
      throw Exception('Failed to parse autocomplete response: $e');
    }
  }

  Future<GooglePlaceDetails> fetchGooglePlace(String placeId) async {
    try {
      final response = await _dio.get(
        '$backendBaseUrl/places/googleplacedetails',
        queryParameters: {'place_id': placeId},
        options: Options(headers: _authHeaders),
      );

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;
        final data = responseData['data'] ?? responseData;

        return GooglePlaceDetails.fromJson(data as Map<String, dynamic>);
      } else {
        throw Exception(
            'Google Place details API Error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('Google Place details Dio error: ${e.response?.data}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint('Google Place details parsing error: $e');
      throw Exception('Parsing error: $e');
    }
  }

  Future<DirectionsResponse> fetchGoogleDirections({
    required double originLat,
    required double originLng,
    required String destinationPlaceId,
  }) async {
    print('Fetching Google Directions for: '
        'Origin: ($originLat, $originLng), '
        'Destination Place ID: $destinationPlaceId');
    try {
      final response = await _dio.get(
        '$backendBaseUrl/places/googledirections',
        queryParameters: {
          'origin': '$originLat,$originLng',
          // 'origin': '9.1538,7.3220',
          'destination': 'place_id:$destinationPlaceId',
        },
        options: Options(headers: _authHeaders),
      );

      if (response.statusCode == 200) {
        print('Google Directions response: ${response.data}');
        final dynamic responseData = response.data;
        final data = responseData['data'] ?? responseData;
        return DirectionsResponse.fromJson(data as Map<String, dynamic>);
      } else {
        throw Exception('Google Directions API Error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print(e);
      debugPrint('Google Directions Dio error: ${e.response?.data}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint('Google Directions parsing error: $e');
      throw Exception('Parsing error: $e');
    }
  }

  Future<MapboxDirectionsResponse> fetchMapboxDirections({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String profile =
        'driving-traffic', // driving, walking, cycling, driving-traffic (recommended)
    List<String>? waypoints, // Optional waypoints in "lat,lng" format
    bool alternatives = true, // Get alternative routes for selection
  }) async {
    final params = <String, String>{
      'origin': '$originLat,$originLng',
      'destination': '$destinationLat,$destinationLng',
    };

    if (profile.isNotEmpty) {
      params['profile'] = profile;
    }

    // Request alternatives for route selection
    if (alternatives) {
      params['alternatives'] = 'true';
    }

    // Add waypoints if provided
    if (waypoints != null && waypoints.isNotEmpty) {
      for (int i = 0; i < waypoints.length; i++) {
        params['waypoint'] = waypoints[i];
      }
    }

    try {
      debugPrint('🔵 [ROUTES] Requesting Mapbox Directions');
      debugPrint('🔵 [ROUTES] Origin: $originLat,$originLng');
      debugPrint('🔵 [ROUTES] Destination: $destinationLat,$destinationLng');
      debugPrint('🔵 [ROUTES] Profile: $profile, Alternatives: $alternatives');
      debugPrint(
          '🔵 [ROUTES] Request URL: $backendBaseUrl/places/mapboxdirections');
      debugPrint('🔵 [ROUTES] Request params: $params');

      final response = await _dio.get(
        '$backendBaseUrl/places/mapboxdirections',
        queryParameters: params,
        options: Options(headers: _authHeaders),
      );

      debugPrint('🔵 [ROUTES] Backend response status: ${response.statusCode}');
      debugPrint('🔵 [ROUTES] Backend response headers: ${response.headers}');
      debugPrint(
          '🔵 [ROUTES] Backend response data type: ${response.data.runtimeType}');
      debugPrint('🔵 [ROUTES] Backend response data: ${response.data}');

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;
        debugPrint(
            '🔵 [ROUTES] Response data keys: ${responseData is Map ? responseData.keys.toList() : "Not a Map"}');

        // Check if backend returned an error message even with status 200
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('message') && 
              responseData.containsKey('status') &&
              responseData['status'] != 'success') {
            final errorMessage = responseData['message'] ?? responseData['status'] ?? 'Unknown error';
            debugPrint('🔵 [ROUTES] ❌ Backend returned error: $errorMessage');
            // Re-throw as-is, don't wrap as parsing error
            throw Exception(errorMessage);
          }
        }

        final data = responseData['data'] ?? responseData;
        debugPrint('🔵 [ROUTES] Parsing data: ${data.runtimeType}');
        debugPrint(
            '🔵 [ROUTES] Data keys: ${data is Map ? data.keys.toList() : "Not a Map"}');

        final directionsResponse =
            MapboxDirectionsResponse.fromJson(data as Map<String, dynamic>);

        debugPrint(
            '🔵 [ROUTES] ✅ Successfully parsed MapboxDirectionsResponse');
        debugPrint(
            '🔵 [ROUTES] Routes count: ${directionsResponse.routes.length}');

        if (directionsResponse.routes.isNotEmpty) {
          for (int i = 0; i < directionsResponse.routes.length; i++) {
            final route = directionsResponse.routes[i];
            debugPrint(
                '🔵 [ROUTES] Route $i: distance=${route.distance}m, duration=${route.duration}s, legs=${route.legs.length}');
          }
        } else {
          debugPrint('🔵 [ROUTES] ⚠️ WARNING: Routes list is EMPTY!');
          // Throw exception if routes are empty - this indicates an error
          throw Exception('No routes found. Please check your connection and try again.');
        }

        return directionsResponse;
      } else {
        debugPrint(
            '🔵 [ROUTES] ❌ ERROR: Backend returned status ${response.statusCode}');
        debugPrint('🔵 [ROUTES] Response body: ${response.data}');
        throw Exception('Mapbox Directions API Error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('🔵 [ROUTES] ❌ DioException occurred');
      debugPrint('🔵 [ROUTES] Error type: ${e.type}');
      debugPrint('🔵 [ROUTES] Error message: ${e.message}');
      debugPrint('🔵 [ROUTES] Response status: ${e.response?.statusCode}');
      debugPrint('🔵 [ROUTES] Response data: ${e.response?.data}');
      debugPrint('🔵 [ROUTES] Request options: ${e.requestOptions.uri}');
      throw Exception('Network error: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('🔵 [ROUTES] ❌ Exception occurred');
      debugPrint('🔵 [ROUTES] Error: $e');
      debugPrint('🔵 [ROUTES] Stack trace: $stackTrace');
      
      // Don't wrap backend errors as parsing errors
      // If exception message indicates backend error, throw as-is
      final errorString = e.toString();
      if (errorString.contains('Failed to get') || 
          errorString.contains('Unable to complete') ||
          errorString.contains('No routes found')) {
        // This is a backend error, not a parsing error - re-throw as-is
        rethrow;
      }
      
      // Otherwise, it's likely a parsing error
      throw Exception('Parsing error: $e');
    }
  }

  // Helper method to safely parse distance meters
  int _parseDistanceMeters(dynamic distance) {
    if (distance == null) return 0;
    if (distance is int) return distance;
    if (distance is double) return distance.round();
    if (distance is String) {
      return int.tryParse(distance) ?? 0;
    }
    return 0;
  }

  double metersToKm(int meters) {
    return meters / 1000;
  }

// Or, if you want a string with 1 decimal:
  String metersToKmString(int meters) {
    return (meters / 1000).toStringAsFixed(1);
  }

  Future<List<Point>> decodeGooglePolyline(String encodedPolyline) async {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints =
        polylinePoints.decodePolyline(encodedPolyline);

    List<Point> mapboxPoints = [];
    for (var point in decodedPoints) {
      mapboxPoints
          .add(Point(coordinates: Position(point.longitude, point.latitude)));
    }
    return mapboxPoints;
  }

  /// Map Matching API for snapping GPS traces to road network
  /// Used sparingly for edge cases to minimize API usage
  Future<List<LatLng>> mapMatchGpsTrace({
    required List<MapMatchingCoordinate> coordinates,
    List<double>? radiuses, // Search radius per coordinate (optional)
    String approach = 'unrestricted', // 'unrestricted' or 'curb'
  }) async {
    if (coordinates.isEmpty) {
      throw Exception('Coordinates list cannot be empty');
    }

    final payload = {
      'coordinates': coordinates
          .map((coord) => {
                'lat': coord.lat,
                'lng': coord.lng,
                'timestamp': coord.timestamp?.millisecondsSinceEpoch,
              })
          .toList(),
      'approach': approach,
    };

    // Add radiuses if provided
    if (radiuses != null && radiuses.isNotEmpty) {
      payload['radiuses'] = radiuses;
    }

    try {
      debugPrint(
          '🗺️ Calling Map Matching API with ${coordinates.length} coordinates');

      final response = await _dio.post(
        '$backendBaseUrl/places/mapboxmapmatching',
        data: payload,
        options: Options(headers: _authHeaders),
      );

      if (response.statusCode == 200) {
        final dynamic responseData = response.data;
        final data = responseData['data'] ?? responseData;

        // Parse Map Matching response
        if (data is Map<String, dynamic> && data.containsKey('matchings')) {
          final matchings = data['matchings'] as List;

          if (matchings.isNotEmpty) {
            final firstMatching = matchings[0] as Map<String, dynamic>;
            final geometry = firstMatching['geometry'] as Map<String, dynamic>;
            final coordinates = geometry['coordinates'] as List;

            // Convert coordinates to LatLng
            return coordinates.map<LatLng>((coord) {
              final coordList = coord as List;
              return LatLng(coordList[1] as double,
                  coordList[0] as double); // [lng, lat] -> LatLng(lat, lng)
            }).toList();
          }
        }

        // If no matchings found, return original coordinates
        debugPrint('⚠️ No map matching results found');
        return coordinates
            .map((coord) => LatLng(coord.lat, coord.lng))
            .toList();
      } else {
        throw Exception('Map Matching API Error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('Map Matching Dio error: ${e.response?.data}');

      // Fallback to original coordinates on network error
      debugPrint('🔄 Map Matching failed, using original coordinates');
      return coordinates.map((coord) => LatLng(coord.lat, coord.lng)).toList();
    } catch (e) {
      debugPrint('Map Matching parsing error: $e');

      // Fallback to original coordinates on parsing error
      return coordinates.map((coord) => LatLng(coord.lat, coord.lng)).toList();
    }
  }
}

/// Data class for Map Matching coordinates with optional timestamp
class MapMatchingCoordinate {
  final double lat;
  final double lng;
  final DateTime? timestamp;

  MapMatchingCoordinate({
    required this.lat,
    required this.lng,
    this.timestamp,
  });

  factory MapMatchingCoordinate.fromGeolocatorPosition(geo.Position position,
      {DateTime? timestamp}) {
    return MapMatchingCoordinate(
      lat: position.latitude,
      lng: position.longitude,
      timestamp: timestamp ?? position.timestamp,
    );
  }

  factory MapMatchingCoordinate.fromLatLng(LatLng latLng,
      {DateTime? timestamp}) {
    return MapMatchingCoordinate(
      lat: latLng.latitude,
      lng: latLng.longitude,
      timestamp: timestamp,
    );
  }
}

class GooglePlaceDetails {
  GooglePlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.rating,
    this.userRatingsTotal,
    this.phoneNumber,
    this.website,
    this.weekdayText,
  });
  final String placeId;
  final String name;
  final String formattedAddress;
  final double lat;
  final double lng;
  final double? rating;
  final int? userRatingsTotal;
  final String? phoneNumber;
  final String? website;
  final List<String>? weekdayText;

  factory GooglePlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry']?['location'] ?? {};
    final openingHours = json['opening_hours'] ?? {};
    return GooglePlaceDetails(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      formattedAddress: json['formatted_address'] as String,
      lat: (geometry['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (geometry['lng'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: json['user_ratings_total'] as int?,
      phoneNumber: json['formatted_phone_number'] as String?,
      website: json['website'] as String?,
      weekdayText: (openingHours['weekday_text'] as List?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }
}
