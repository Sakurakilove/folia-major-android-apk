// JavaScript Number.toString's decimal/exponent cutoffs and -0 spelling are part of original persisted/cache/layout keys.
double jsRound(double value) {
  if (!value.isFinite || value == 0 || value.abs() >= 4503599627370496) {
    return value;
  }
  if (value < 0 && value >= -.5) return -0.0;
  final lower = value.floorToDouble();
  return value - lower < .5 ? lower : lower + 1;
}

String jsNumberString(double value) {
  if (value.isNaN) return 'NaN';
  if (value == double.infinity) return 'Infinity';
  if (value == double.negativeInfinity) return '-Infinity';
  if (value == 0) return '0';
  final negative = value < 0,
      parts = value.abs().toString().toLowerCase().split('e');
  final mantissa = parts.first,
      exponent = parts.length == 2 ? int.parse(parts[1]) : 0;
  final dot = mantissa.indexOf('.');
  var digits = mantissa.replaceAll('.', ''),
      position = (dot < 0 ? mantissa.length : dot) + exponent;
  while (digits.length > 1 && digits.startsWith('0')) {
    digits = digits.substring(1);
    position--;
  }
  while (digits.length > 1 && digits.endsWith('0')) {
    digits = digits.substring(0, digits.length - 1);
  }
  final sign = negative ? '-' : '';
  if (value.abs() >= 1e21 || value.abs() < 1e-6) {
    final e = position - 1,
        significand = digits.length == 1
            ? digits
            : '${digits[0]}.${digits.substring(1)}';
    return '$sign${significand}e${e < 0 ? '' : '+'}$e';
  }
  if (position <= 0) return '${sign}0.${'0' * -position}$digits';
  if (position >= digits.length) {
    return '$sign$digits${'0' * (position - digits.length)}';
  }
  return '$sign${digits.substring(0, position)}.${digits.substring(position)}';
}
