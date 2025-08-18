import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static SettingsService get instance => _instance;

  // Callback for theme changes
  VoidCallback? _onThemeChanged;
  // Callback for any settings changes that should refresh UI (e.g., currency)
  VoidCallback? _onSettingsChanged;
  // Callback for app data changes (e.g., transactions added externally)
  VoidCallback? _onDataChanged;

  // Settings keys
  static const String _currencyKey = 'currency';
  static const String _currencyFormatKey = 'currency_format';
  static const String _darkModeKey = 'dark_mode';
  static const String _languageKey = 'language';
  static const String _accentColorKey = 'accent_color';
  static const String _notificationsKey = 'notifications';
  static const String _autopayReminderDaysKey = 'autopay_reminder_days';
  static const String _homePeriodKey = 'home_period'; // new: home summary range
  static const String _customCurrencySymbolKey = 'custom_currency_symbol';

  // Currency symbols mapping
  static const Map<String, String> _currencySymbols = {
    'LYD': 'LYD',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CAD': 'C\$',
    'AUD': 'A\$',
  };

  // Default values
  String _currency = 'LYD';
  String _currencyFormat = 'standard';
  bool _isDarkMode = true;
  String _language = 'English';
  Color _accentColor = Colors.blueAccent;
  bool _notificationsEnabled = true;
  int _autopayReminderDays = 3; // days before due to notify; 0 = off
  String _homePeriod = 'month'; // month | 3m | 6m | year
  String _customCurrencySymbol = '';

  // Getters
  String get currency => _currency;
  String get currencyFormat => _currencyFormat;
  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  Color get accentColor => _accentColor;
  bool get notificationsEnabled => _notificationsEnabled;
  int get autopayReminderDays => _autopayReminderDays;
  String get homePeriod => _homePeriod;
  String get customCurrencySymbol => _customCurrencySymbol;
  
  // Get currency symbol
  String get currencySymbol {
    if (_currency == 'CUSTOM' && _customCurrencySymbol.isNotEmpty) {
      return _customCurrencySymbol;
    }
    return _currencySymbols[_currency] ?? _currency;
  }

  // Set theme change callback
  void setThemeChangeCallback(VoidCallback callback) {
    _onThemeChanged = callback;
  }

  // Set general settings change callback
  void setSettingsChangeCallback(VoidCallback callback) {
    _onSettingsChanged = callback;
  }

  // Set data change callback
  void setDataChangeCallback(VoidCallback callback) {
    _onDataChanged = callback;
  }

  // Notify data change
  void notifyDataChanged() {
    _onDataChanged?.call();
  }

  // Initialize settings
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    _currency = prefs.getString(_currencyKey) ?? 'LYD';
    _currencyFormat = prefs.getString(_currencyFormatKey) ?? 'standard';
    _isDarkMode = prefs.getBool(_darkModeKey) ?? true;
    _language = prefs.getString(_languageKey) ?? 'English';
    _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    _autopayReminderDays = prefs.getInt(_autopayReminderDaysKey) ?? 3;
    _homePeriod = prefs.getString(_homePeriodKey) ?? 'month';
    _customCurrencySymbol = prefs.getString(_customCurrencySymbolKey) ?? '';
    
    // Load accent color
    final accentColorValue = prefs.getInt(_accentColorKey) ?? Colors.blueAccent.value;
    _accentColor = Color(accentColorValue);
  }

  // Save settings
  Future<void> saveSettings({
    String? currency,
    String? currencyFormat,
    bool? isDarkMode,
    String? language,
    Color? accentColor,
    bool? notificationsEnabled,
    int? autopayReminderDays,
    String? homePeriod,
    String? customCurrencySymbol,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    bool notifyGeneralChange = false;

    if (currency != null) {
      _currency = currency;
      await prefs.setString(_currencyKey, currency);
      notifyGeneralChange = true;
    }

    if (customCurrencySymbol != null) {
      _customCurrencySymbol = customCurrencySymbol;
      await prefs.setString(_customCurrencySymbolKey, customCurrencySymbol);
      // If user sets a custom symbol but currency isn't CUSTOM, switch to CUSTOM automatically
      if (_currency != 'CUSTOM') {
        _currency = 'CUSTOM';
        await prefs.setString(_currencyKey, 'CUSTOM');
      }
      notifyGeneralChange = true;
    }

    if (currencyFormat != null) {
      _currencyFormat = currencyFormat;
      await prefs.setString(_currencyFormatKey, currencyFormat);
      notifyGeneralChange = true;
    }

    if (isDarkMode != null) {
      _isDarkMode = isDarkMode;
      await prefs.setBool(_darkModeKey, isDarkMode);
      // Notify theme change
      _onThemeChanged?.call();
    }

    if (language != null) {
      _language = language;
      await prefs.setString(_languageKey, language);
      notifyGeneralChange = true;
    }

    if (accentColor != null) {
      _accentColor = accentColor;
      await prefs.setInt(_accentColorKey, accentColor.value);
      _onThemeChanged?.call(); // notify for accent change
    }

    if (notificationsEnabled != null) {
      _notificationsEnabled = notificationsEnabled;
      await prefs.setBool(_notificationsKey, notificationsEnabled);
      notifyGeneralChange = true;
    }

    if (autopayReminderDays != null) {
      _autopayReminderDays = autopayReminderDays;
      await prefs.setInt(_autopayReminderDaysKey, autopayReminderDays);
      notifyGeneralChange = true;
    }

    if (homePeriod != null) {
      _homePeriod = homePeriod;
      await prefs.setString(_homePeriodKey, homePeriod);
      notifyGeneralChange = true;
    }

    if (notifyGeneralChange) {
      _onSettingsChanged?.call();
    }
  }

  // Format currency based on settings
  String formatCurrency(double amount) {
    final symbol = currencySymbol;
    
    switch (_currencyFormat) {
      case 'compact':
        if (amount >= 1000000) {
          return '$symbol ${(amount / 1000000).toStringAsFixed(1)}M';
        } else if (amount >= 1000) {
          return '$symbol ${(amount / 1000).toStringAsFixed(1)}K';
        }
        return '$symbol ${amount.toStringAsFixed(0)}';
      case 'no_decimal':
        return '$symbol ${amount.round().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
      case 'standard':
      default:
        return '$symbol ${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
    }
  }

  // Clear all settings
  Future<void> clearAllSettings() async {
    print('DEBUG: Starting clearAllSettings...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('DEBUG: SharedPreferences cleared');
    
    // Reset to defaults
    _currency = 'LYD';
    _currencyFormat = 'standard';
    _isDarkMode = true;
    _language = 'English';
    _accentColor = Colors.blueAccent;
    _notificationsEnabled = true;
    _autopayReminderDays = 3;
    _homePeriod = 'month';
    _customCurrencySymbol = '';
    print('DEBUG: Default values reset');
    
    // Notify theme change
    _onThemeChanged?.call();
    // Notify general settings change as well
    _onSettingsChanged?.call();
    print('DEBUG: clearAllSettings completed successfully');
  }
}