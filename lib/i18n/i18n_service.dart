import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class I18n {
  static final I18n _instance = I18n._internal();
  factory I18n() => _instance;
  I18n._internal();

  String locale = 'es'; // default
  final Map<String, String> _strings = {};

  Future<void> load([String? localeCode]) async {
    if (localeCode != null) locale = localeCode;
    try {
      final content = await rootBundle.loadString('lib/i18n/$locale.json');
      final Map<String, dynamic> parsed = json.decode(content);
      _strings.clear();
      parsed.forEach((k, v) {
        _strings[k] = v.toString();
      });
    } catch (e) {
      // fallback empty
      print('I18n load error for locale "$locale" : $e');
    }
  }

  String t(String key, [Map<String, String>? params]) {
    var value = _strings[key] ?? key;
    if (params != null) {
      params.forEach((k, v) {
        value = value.replaceAll(':$k', v);
      });
    }
    return value;
  }

  static Future<void> init([String? localeCode]) async => await I18n().load(localeCode);
  static String of(String key, [Map<String, String>? params]) => I18n().t(key, params);
}
