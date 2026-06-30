import 'package:flutter_test/flutter_test.dart';
import 'package:ilithid/shared/utils/validation.dart';

void main() {
  group('ValidationUtils - Email validation', () {
    test('should return true for valid email formats', () {
      expect(ValidationUtils.isValidEmail('test@example.com'), isTrue);
      expect(ValidationUtils.isValidEmail('user.name@domain.co.uk'), isTrue);
      expect(ValidationUtils.isValidEmail('some_name@domain.io'), isTrue);
    });

    test('should return false for invalid email formats', () {
      expect(ValidationUtils.isValidEmail('testexample.com'), isFalse);
      expect(ValidationUtils.isValidEmail('test@'), isFalse);
      expect(ValidationUtils.isValidEmail('test@example'), isFalse);
      expect(ValidationUtils.isValidEmail(''), isFalse);
    });
  });

  group('ValidationUtils - Hex ID validation', () {
    test('should return true for valid hexadecimal campaign IDs', () {
      expect(ValidationUtils.isValidHexId('a1b2c3'), isTrue);
      expect(ValidationUtils.isValidHexId('1234567890abcdef'), isTrue);
      expect(ValidationUtils.isValidHexId('ABCDEF'), isTrue);
    });

    test('should return false for invalid hexadecimal campaign IDs', () {
      expect(ValidationUtils.isValidHexId('a1b2c'), isFalse); // too short
      expect(ValidationUtils.isValidHexId('xyz123'), isFalse); // non-hex characters
      expect(ValidationUtils.isValidHexId(''), isFalse);
    });
  });
}
