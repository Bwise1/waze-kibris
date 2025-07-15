import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:waze_kibris/core/models/location/recent_location.dart';
import 'package:waze_kibris/core/services/local_storage.dart';

class RecentLocationsService {
  RecentLocationsService(this._localStorage);
  static const String _storageKey = 'recent_locations';
  static const int _maxRecentLocations = 20;

  final ILocalStorage _localStorage;

  /// Get all recent locations sorted by last visited and frequency
  Future<List<RecentLocation>> getRecentLocations() async {
    try {
      final dynamic rawData = _localStorage.get<dynamic>(_storageKey);
      if (rawData == null) return [];

      final List<dynamic> jsonList = rawData as List<dynamic>;
      final List<RecentLocation> locations = jsonList
          .map((json) => RecentLocation.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by frequency (visitCount) first, then by last visited
      locations.sort((a, b) {
        final frequencyComparison = b.visitCount.compareTo(a.visitCount);
        if (frequencyComparison != 0) return frequencyComparison;
        return b.lastVisited.compareTo(a.lastVisited);
      });

      return locations;
    } catch (e) {
      debugPrint('❌ Service: Error loading recent locations: $e');
      return [];
    }
  }

  /// Add or update a recent location
  Future<void> addRecentLocation(RecentLocation location) async {
    try {
      debugPrint('🔥 Service: Adding recent location ${location.name}');
      final existingLocations = await getRecentLocations();
      debugPrint(
          '🔥 Service: Found ${existingLocations.length} existing locations');

      // Check if location already exists
      final existingIndex = existingLocations.indexWhere(
        (existing) => existing.placeId == location.placeId,
      );

      if (existingIndex != -1) {
        // Update existing location with new visit count and timestamp
        final existing = existingLocations[existingIndex];
        existingLocations[existingIndex] = existing.copyWith(
          lastVisited: DateTime.now(),
          visitCount: existing.visitCount + 1,
        );
        debugPrint(
          '🔥 Service: Updated existing location, new visit count: ${existing.visitCount + 1}',
        );
      } else {
        // Add new location
        existingLocations.insert(
            0,
            location.copyWith(
              lastVisited: DateTime.now(),
            ));
        debugPrint('🔥 Service: Added new location');
      }

      // Keep only the most recent N locations
      if (existingLocations.length > _maxRecentLocations) {
        existingLocations.removeRange(
            _maxRecentLocations, existingLocations.length);
      }

      // Save to storage - let ILocalStorage handle JSON encoding automatically
      final locationData = existingLocations.map((location) => location.toJson()).toList();
      await _localStorage.save<List<Map<String, dynamic>>>(_storageKey, locationData);
      debugPrint(
          '🔥 Service: Saved ${existingLocations.length} locations to storage');
    } catch (e) {
      debugPrint('❌ Service: Error saving recent location: $e');
    }
  }

  /// Remove a specific recent location
  Future<void> removeRecentLocation(String placeId) async {
    try {
      final locations = await getRecentLocations();
      locations.removeWhere((location) => location.placeId == placeId);

      final locationData = locations.map((location) => location.toJson()).toList();
      await _localStorage.save<List<Map<String, dynamic>>>(_storageKey, locationData);
    } catch (e) {
      debugPrint('❌ Service: Error removing recent location: $e');
    }
  }

  /// Clear all recent locations
  Future<void> clearRecentLocations() async {
    try {
      await _localStorage.delete(_storageKey);
    } catch (e) {
      print('Error clearing recent locations: $e');
    }
  }

  /// Get category icon based on place type or name
  String _getCategoryIcon(String name, String? category) {
    final lowerName = name.toLowerCase();

    if (category != null) {
      switch (category.toLowerCase()) {
        case 'home':
          return 'home';
        case 'work':
          return 'work';
        case 'gas':
        case 'fuel':
          return 'gas';
        case 'food':
        case 'restaurant':
          return 'food';
        case 'hospital':
        case 'medical':
          return 'hospital';
        case 'park':
          return 'park';
      }
    }

    // Fallback to name-based detection
    if (lowerName.contains('home')) return 'home';
    if (lowerName.contains('work') || lowerName.contains('office')) {
      return 'work';
    }
    if (lowerName.contains('gas') || lowerName.contains('fuel')) return 'gas';
    if (lowerName.contains('restaurant') || lowerName.contains('food')) {
      return 'food';
    }
    if (lowerName.contains('hospital') || lowerName.contains('medical')) {
      return 'hospital';
    }
    if (lowerName.contains('park')) return 'park';

    return 'location'; // Default icon
  }
}
