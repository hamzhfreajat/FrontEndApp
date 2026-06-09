import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import '../models/location.dart' as loc;

class LocationService {
  /// Request permissions and get current coordinates
  static Future<Position?> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    } catch (e) {
      if (kDebugMode) print('Error getting position: $e');
      return null;
    }
  }

  /// Retrieves the region and city as a map
  static Future<Map<String, String>?> getSystemLocationParts() async {
    final position = await _getCurrentPosition();
    if (position == null) return null;

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        if (kDebugMode) print('Geocoded Placemark: $place');
        
        String regionMatch = place.subLocality ?? '';
        String cityMatch = place.locality ?? place.administrativeArea ?? place.country ?? '';
        
        if (regionMatch.trim().isEmpty) regionMatch = '';
        if (cityMatch.trim().isEmpty) cityMatch = '';
        
        if (cityMatch.isEmpty && regionMatch.isEmpty) return null;

        return {
          'city': cityMatch.trim(),
          'region': regionMatch.trim(),
        };
      }
    } catch (e) {
      if (kDebugMode) print('Geocoding error: $e');
    }
    return null;
  }

  /// Maps system parts against our DB schema
  static loc.Region? mapSystemToDBRegion(Map<String, String>? sysLocation, List<loc.City> dbCities) {
    if (sysLocation == null || dbCities.isEmpty) return null;
    
    final sysCity = sysLocation['city']?.toLowerCase() ?? '';
    final sysRegion = sysLocation['region']?.toLowerCase() ?? '';
    
    // First, try to match the City exactly if provided
    for (var dbCity in dbCities) {
      bool cityMatch = false;
      if (sysCity.isNotEmpty && (dbCity.nameEn.toLowerCase().contains(sysCity) || 
                                 sysCity.contains(dbCity.nameEn.toLowerCase()) || 
                                 dbCity.nameAr.contains(sysCity) || 
                                 sysCity.contains(dbCity.nameAr))) {
        cityMatch = true;
      }
      
      // If we matched the city, or sysCity was empty (so we search all cities)
      if (cityMatch || sysCity.isEmpty) {
        for (var region in dbCity.regions) {
          if (sysRegion.isNotEmpty) {
            if (sysRegion.contains(region.nameEn.toLowerCase()) || 
                region.nameEn.toLowerCase().contains(sysRegion) ||
                sysRegion.contains(region.nameAr) ||
                region.nameAr.contains(sysRegion)) {
              return region;
            }
          }
        }
      }
      
      // If we found the correct DB City but NO Region matched inside it,
      // what do we do? We return null so the fallback catches it, or we could return Region? No, just null.
    }
    
    // Fallback: brutal scan for region string across ALL cities just in case city name was weird
    if (sysRegion.isNotEmpty) {
      for (var city in dbCities) {
        for (var region in city.regions) {
          if (sysRegion.contains(region.nameEn.toLowerCase()) || 
              region.nameEn.toLowerCase().contains(sysRegion) ||
              sysRegion.contains(region.nameAr) ||
              region.nameAr.contains(sysRegion)) {
            return region;
          }
        }
      }
    }
    return null;
  }
}
