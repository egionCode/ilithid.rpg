class ValidationUtils {
  /// Validates if the given [email] has a correct email format.
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Validates if the [hexId] is a valid hexadecimal ID (used for campaign joins).
  /// Must be at least 6 characters long and contain only hex digits.
  static bool isValidHexId(String hexId) {
    final hexRegex = RegExp(r'^[0-9a-fA-F]{6,}$');
    return hexRegex.hasMatch(hexId);
  }
}
