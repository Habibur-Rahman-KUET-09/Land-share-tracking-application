/// The bar a Kistify password has to clear.
///
/// Deliberately modest: length is what actually resists guessing, and a
/// thicket of character-class rules mostly drives people to `Password1!`
/// and a sticky note. Firebase already rate-limits sign-in attempts server
/// side, so this guards against the weak end of the distribution rather
/// than trying to be the whole defence.
class PasswordPolicy {
  PasswordPolicy._();

  static const minLength = 8;

  /// Returns an l10n key describing what's wrong, or null when the password
  /// is acceptable. Returning a key (not a sentence) keeps the Bangla and
  /// English wording in app_strings.dart with everything else.
  static String? problemKey(String? password) {
    final p = password ?? '';
    if (p.length < minLength) return 'password_too_short';
    if (!p.contains(RegExp(r'[A-Za-z]'))) return 'password_needs_letter';
    if (!p.contains(RegExp(r'[0-9]'))) return 'password_needs_digit';
    // Catches the handful of passwords that clear the rules above and are
    // still the first thing anyone would try.
    if (_tooCommon.contains(p.toLowerCase())) return 'password_too_common';
    return null;
  }

  static const _tooCommon = {
    'password1',
    'password123',
    'passw0rd',
    '12345678',
    '123456789',
    '1234567890',
    'qwerty123',
    'abc12345',
    'iloveyou1',
    'admin123',
    'kistify123',
  };
}
