import 'package:geolocator/geolocator.dart';

class LocationService {

  Future<Position> getCurrentLocation() async {

    // 1. Check service
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled.';
    }

    // 2. Permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw 'Location permission denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied. Enable from settings.';
    }

    try {
      // 3. TRY REAL GPS FIRST (10 sec)
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

    } catch (e) {
      print("GPS timeout → trying last known position");

      // 4. FALLBACK TO LAST KNOWN
      Position? last = await Geolocator.getLastKnownPosition();

      if (last != null) {
        return last;
      }

      // 5. FINAL FALLBACK → LOW ACCURACY
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
    }
  }
}
