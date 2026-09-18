import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// NFR: "Bangla + English উভয় ভাষা সাপোর্ট (UI language toggle)". Backed by
/// [AppStrings] (see lib/l10n/app_strings.dart) for the actual translation
/// lookup — this provider just holds/persists which language is active and
/// triggers a rebuild of anything watching it when the user toggles.
class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'ui_language';

  String _language = 'bn'; // 'bn' | 'en'
  String get language => _language;
  bool get isBangla => _language == 'bn';

  /// Handed to MaterialApp so Flutter's own widgets follow the same toggle —
  /// without it the date pickers stay English no matter what the app's text
  /// says, because MaterialApp falls back to its default English
  /// localizations.
  Locale get locale => Locale(_language);

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString(_prefsKey) ?? 'bn';
    notifyListeners();
  }

  Future<void> toggle() async {
    _language = _language == 'bn' ? 'en' : 'bn';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _language);
  }
}
