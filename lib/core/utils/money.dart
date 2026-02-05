int rupeesToMinor(String input) {
  final cleaned = input.trim().replaceAll(',', '');
  final value = double.tryParse(cleaned);
  if (value == null) throw FormatException('Invalid amount');
  return (value * 100).round(); // store as paisa
}

String minorToRupees(int minor) {
  final v = minor / 100.0;
  return v.toStringAsFixed(2);
}
