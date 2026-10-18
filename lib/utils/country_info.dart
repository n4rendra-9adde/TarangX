import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:Bloomee/core/constants/setting_keys.dart';
import 'package:country_codes/country_codes.dart';
import 'package:Bloomee/services/db/dao/settings_dao.dart';
import 'package:Bloomee/services/db/db_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class CountryInfoService {
  static const String defaultCountryCode = 'IN';
  static bool _countryCodesInitialized = false;

  const CountryInfoService._();

  static String normalizeCountryCode(String? value) {
    final normalized = (value ?? '').trim().toUpperCase().replaceAll(
          RegExp(r'[^A-Z]'),
          '',
        );
    return normalized.length == 2 ? normalized : '';
  }

  static Future<String?> readCachedCountryCode(SettingsDAO settingsDao) async {
    final cached = normalizeCountryCode(
      await settingsDao.getSettingStr(SettingKeys.countryCode),
    );
    return cached.isEmpty ? null : cached;
  }

  static Future<String?> resolveAndCacheCountryCodeFromDeviceLocale({
    required SettingsDAO settingsDao,
  }) async {
    final code = await resolveCountryCodeFromDeviceLocale();
    if (code == null) {
      return null;
    }

    await settingsDao.putSettingStr(SettingKeys.countryCode, code);
    return code;
  }

  static Future<String?> resolveCountryCodeFromDeviceLocale() async {
    // 1. Flutter Engine platform dispatcher (cross-platform, 0ms, zero dependency)
    try {
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      final engineCountry = normalizeCountryCode(dispatcher.locale.countryCode);
      if (engineCountry.isNotEmpty) {
        return engineCountry;
      }

      for (final loc in dispatcher.locales) {
        final code = normalizeCountryCode(loc.countryCode);
        if (code.isNotEmpty) {
          return code;
        }
      }
    } catch (_) {}

    // 2. Platform environment locale (Linux, Android, Windows, macOS)
    try {
      final rawLocale = Platform.localeName;
      final cleaned = rawLocale.replaceAll(RegExp(r'\..*$'), '');
      final parts = cleaned.split(RegExp(r'[_-]'));
      if (parts.length > 1) {
        final code = normalizeCountryCode(parts[1]);
        if (code.isNotEmpty) {
          return code;
        }
      }
    } catch (_) {}

    // 3. CountryCodes package plugin (if available on current platform)
    try {
      if (!_countryCodesInitialized) {
        await CountryCodes.init();
        _countryCodesInitialized = true;
      }

      final locale = CountryCodes.getDeviceLocale();
      final code = normalizeCountryCode(locale?.countryCode);
      if (code.isNotEmpty) {
        return code;
      }
    } catch (_) {}

    return null;
  }

  static Future<String> resolveAndCacheCountryCode({
    required SettingsDAO settingsDao,
    bool forceRefresh = false,
  }) async {
    final cached = await readCachedCountryCode(settingsDao);
    final autoGetCountry =
        await settingsDao.getSettingBool(SettingKeys.autoGetCountry) ?? true;

    if (!forceRefresh && cached != null) {
      return cached;
    }

    if (forceRefresh || autoGetCountry || cached == null) {
      // Step A: Fast network geo-IP lookup for accurate physical location
      final fetched = await _fetchCountryCode();
      if (fetched != null && fetched.isNotEmpty) {
        await settingsDao.putSettingStr(SettingKeys.countryCode, fetched);
        log('Resolved country code from network: $fetched',
            name: 'CountryInfoService');
        return fetched;
      }

      // Step B: Offline fallback to device locale
      final deviceCode = await resolveCountryCodeFromDeviceLocale();
      if (deviceCode != null && deviceCode.isNotEmpty) {
        await settingsDao.putSettingStr(SettingKeys.countryCode, deviceCode);
        log('Resolved country code from device locale: $deviceCode',
            name: 'CountryInfoService');
        return deviceCode;
      }
    }

    if (cached != null) {
      return cached;
    }

    // Final fallback
    const fallback = defaultCountryCode;
    await settingsDao.putSettingStr(SettingKeys.countryCode, fallback);
    log(
      'Country lookup failed; using fallback country $fallback',
      name: 'CountryInfoService',
    );
    return fallback;
  }

  // Policy resolver for plugin allowlist checks.
  // Uses selected cached country only and never performs network lookup.
  static Future<String> resolveCountryCodeForPolicyCheck({
    required SettingsDAO settingsDao,
    bool forceRefresh = false,
  }) async {
    final cached = await readCachedCountryCode(settingsDao);
    return cached ?? '';
  }

  static Future<String?> _fetchCountryCode() async {
    final fastEndpoints = [
      Uri.parse('https://api.country.is/'),
      Uri.parse('https://ipinfo.io/json'),
      Uri.parse('https://ipwho.is/'),
    ];

    final client = http.Client();
    try {
      final futures = fastEndpoints.map((uri) async {
        try {
          final response =
              await client.get(uri).timeout(const Duration(milliseconds: 2500));
          if (response.statusCode != 200) return null;
          final json = jsonDecode(utf8.decode(response.bodyBytes));
          if (json is! Map) return null;
          final map = Map<String, dynamic>.from(json);
          if (map['error'] == true) return null;
          final code = normalizeCountryCode(
            map['countryCode'] ??
                map['country_code'] ??
                map['country'] ??
                map['countryCode2'],
          );
          return code.isNotEmpty ? code : null;
        } catch (_) {
          return null;
        }
      }).toList();

      final results = await Future.wait(futures);
      for (final res in results) {
        if (res != null && res.isNotEmpty) {
          return res;
        }
      }
    } finally {
      client.close();
    }

    return null;
  }
}

Future<String> getCountry() {
  return CountryInfoService.resolveAndCacheCountryCode(
    settingsDao: SettingsDAO(DBProvider.db),
  );
}
