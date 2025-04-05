import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waze_kibris/common.dart';

class UserCoordinates {
  Position? position;

  Future<Position?> getUserCoordinate(BuildContext context) async {
    bool coordinateEnabled = await handleLocationPermission(context);

    if (coordinateEnabled) {
      position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    }
    // print(coordinateEnabled);
    return position;
  }

  static Future<bool> handleLocationPermission(
    BuildContext context, {
    Function()? onTurnOnGPS,
  }) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator
        .isLocationServiceEnabled(); // this check if the location feature of the device is turned on by user
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent.withOpacity(0.8),
          content: Text(
            style: styles.typography.f.copyWith(height: 1.5),
            'Location services are disabled. Please enable the services from your device Settings.',
          ),
        ),
      );

      if (onTurnOnGPS != null) {
        ///call this function out side this function caller to turn on GPS
        onTurnOnGPS();
      }

      return serviceEnabled;
    }
    // print('I am here now..');

    ///check if the permission granted
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent.withOpacity(0.8),
            content: Text(
              style: styles.typography.body.copyWith(height: 1.5),
              'Location permissions are denied',
            ),
          ),
        );
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent.withOpacity(0.8),
          content: Text(
            style: styles.typography.body.copyWith(height: 1.5),
            'Location permissions are permanently denied, we cannot request'
            ' permissions.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  static turnOnGPS(BuildContext context) {
    Geolocator.openLocationSettings().then((value) {
      log('Done with location Settings');

      ///get user coordinate after turn on gps
      UserCoordinates.getAndSetUserCoordinate(context);
    });
  }

  ///get and set user gps coordinate in AuthProvider class
  static Future<Position?> getAndSetUserCoordinate(BuildContext context) async {
    final status = await UserCoordinates.handleLocationPermission(
      context,
    );

    if (status) {
      final position = await UserCoordinates().getUserCoordinate(context);
      // auth.setUserCoordinate = position!;
      return position;
    } else {
      return null;
    }
  }
}
