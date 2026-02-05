import 'package:intl/intl.dart';

/// Returns YYYY-MM in device local time.
String monthIdFromMillis(int dateMillis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(dateMillis).toLocal();
  return DateFormat('yyyy-MM').format(dt);
}

String currentMonthId() {
  return DateFormat('yyyy-MM').format(DateTime.now().toLocal());
}

String previousMonthId(String monthId) {
  final y = int.parse(monthId.substring(0, 4));
  final m = int.parse(monthId.substring(5, 7));
  final prev = DateTime(y, m - 1, 1); // DateTime auto-wraps year
  final yy = prev.year.toString().padLeft(4, '0');
  final mm = prev.month.toString().padLeft(2, '0');
  return '$yy-$mm';
}

