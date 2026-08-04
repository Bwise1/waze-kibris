import 'package:waze_kibris/core/models/reports/report_response.dart';

/// True if [expiresAt] ISO8601 string is still in the future (UTC).
bool reportExpiresAtIsValid(String expiresAt) {
  try {
    final exp = DateTime.parse(expiresAt).toUtc();
    return DateTime.now().toUtc().isBefore(exp);
  } catch (_) {
    return true;
  }
}

/// Human-readable time until expiry, or null if already expired / invalid.
String? formatExpiresInLabel(String expiresAt) {
  try {
    final exp = DateTime.parse(expiresAt).toLocal();
    final now = DateTime.now();
    if (!now.isBefore(exp)) return null;
    final d = exp.difference(now);
    if (d.inMinutes < 1) return 'Expires in under 1 min';
    if (d.inHours < 1) {
      final m = d.inMinutes;
      return 'Expires in $m min${m == 1 ? '' : 's'}';
    }
    if (d.inHours < 24) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return m == 0
          ? 'Expires in $h hr${h == 1 ? '' : 's'}'
          : 'Expires in ${h}h ${m}m';
    }
    final days = d.inDays;
    return 'Expires in $days day${days == 1 ? '' : 's'}';
  } catch (_) {
    return null;
  }
}

/// Drops reports whose [ReportData.expiresAt] is in the past.
List<ReportData> filterNonExpiredReports(Iterable<ReportData> reports) =>
    reports.where((r) => reportExpiresAtIsValid(r.expiresAt)).toList();
