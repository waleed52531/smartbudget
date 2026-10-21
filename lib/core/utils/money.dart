const maxMinorAmount = 9223372036854775807;

/// Parses decimal rupees exactly, without binary floating-point rounding.
/// Zero is useful for budgets and filters; transactions require a positive value.
int rupeesToMinor(String input) {
  final cleaned = input.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(cleaned)) {
    throw const FormatException(
      'Enter a non-negative amount with at most two decimal places.',
    );
  }
  final parts = cleaned.split('.');
  final minor =
      BigInt.parse(parts[0]) * BigInt.from(100) +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  if (minor > BigInt.from(maxMinorAmount)) {
    throw const FormatException('Amount is too large.');
  }
  return minor.toInt();
}

void requirePositiveAmount(int amount) {
  if (amount <= 0 || amount > maxMinorAmount) {
    throw ArgumentError('Amount must be greater than zero.');
  }
}

void requireNonNegativeAmount(int amount) {
  if (amount < 0 || amount > maxMinorAmount) {
    throw ArgumentError('Amount cannot be negative.');
  }
}

String minorToRupees(int minor) {
  final magnitude = BigInt.from(minor).abs();
  final whole = magnitude ~/ BigInt.from(100);
  final fraction = (magnitude % BigInt.from(100)).toString().padLeft(2, '0');
  return '${minor < 0 ? '-' : ''}$whole.$fraction';
}
