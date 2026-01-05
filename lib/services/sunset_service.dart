import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final sunsetServiceProvider = Provider<SunsetService>((ref) {
  return SunsetService();
});

class SunsetService {
  Future<TimeOfDay?> fetchSunsetTime(DateTime day) async {
    if (kIsWeb) return null;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    final permission = await _ensurePermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
    } catch (_) {
      return null;
    }
    final sunset = _calculateSunsetUtc(
      day.toUtc(),
      position.latitude,
      position.longitude,
    );
    if (sunset == null) return null;
    final local = sunset.toLocal();
    return TimeOfDay(hour: local.hour, minute: local.minute);
  }

  Future<LocationPermission> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  DateTime? _calculateSunsetUtc(DateTime dayUtc, double lat, double lon) {
    final date = DateTime.utc(dayUtc.year, dayUtc.month, dayUtc.day);
    final julianDay = _toJulianDay(date);
    final n = julianDay - 2451545.0 + 0.0008;
    final jStar = n - (lon / 360.0);
    final m = _degToRad(_normalizeDegrees(357.5291 + 0.98560028 * jStar));
    final c = _degToRad(
      1.9148 * sin(m) +
          0.0200 * sin(2 * m) +
          0.0003 * sin(3 * m),
    );
    final lambda = _degToRad(
      _normalizeDegrees(_radToDeg(m) + _radToDeg(c) + 180 + 102.9372),
    );
    final jTransit =
        2451545.0 + jStar + 0.0053 * sin(m) - 0.0069 * sin(2 * lambda);
    final delta = asin(sin(lambda) * sin(_degToRad(23.44)));
    final latRad = _degToRad(lat);
    final cosOmega = (sin(_degToRad(-0.833)) -
            sin(latRad) * sin(delta)) /
        (cos(latRad) * cos(delta));
    if (cosOmega.abs() > 1) {
      return null;
    }
    final omega = acos(cosOmega);
    final jSet = jTransit + _radToDeg(omega) / 360.0;
    return _fromJulianDay(jSet);
  }

  double _toJulianDay(DateTime date) {
    final year = date.year;
    final month = date.month;
    final day = date.day;
    final a = ((14 - month) / 12).floor();
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    final julianDay =
        day + ((153 * m + 2) / 5).floor() + 365 * y + (y / 4).floor() -
            (y / 100).floor() + (y / 400).floor() - 32045;
    return julianDay.toDouble();
  }

  DateTime _fromJulianDay(double jd) {
    final z = jd.floor();
    final f = jd - z;
    final a = (z - 1867216.25) / 36524.25;
    final aInt = z + 1 + a.floor() - (a / 4).floor();
    final b = aInt + 1524;
    final c = ((b - 122.1) / 365.25).floor();
    final d = (365.25 * c).floor();
    final e = ((b - d) / 30.6001).floor();
    final day = b - d - (30.6001 * e).floor() + f;
    final month = e < 14 ? e - 1 : e - 13;
    final year = month > 2 ? c - 4716 : c - 4715;
    final dayInt = day.floor();
    final dayFraction = day - dayInt;
    final secondsInDay = (dayFraction * 86400).round();
    return DateTime.utc(year, month, dayInt).add(Duration(seconds: secondsInDay));
  }

  double _degToRad(double value) => value * pi / 180.0;

  double _radToDeg(double value) => value * 180.0 / pi;

  double _normalizeDegrees(double value) {
    var result = value % 360.0;
    if (result < 0) result += 360.0;
    return result;
  }
}
