import 'package:Bloomee/core/constants/setting_keys.dart';
import 'package:Bloomee/core/theme/app_theme.dart';
import 'package:Bloomee/l10n/app_localizations.dart';
import 'package:Bloomee/l10n/language_options.dart';
import 'package:Bloomee/screens/screen/home_views/setting_views/country_setting.dart';
import 'package:Bloomee/screens/widgets/country_picker_modal.dart';
import 'package:Bloomee/services/db/dao/settings_dao.dart';
import 'package:Bloomee/services/db/db_provider.dart';
import 'package:Bloomee/services/onboarding_service.dart';
import 'package:Bloomee/utils/country_info.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class OnboardingOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingOverlay({super.key, required this.onComplete});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  static const _cardColor = AppTheme.surface;
  static const _fieldColor = AppTheme.surfaceElevated;

  final SettingsDAO _settingsDao = SettingsDAO(DBProvider.db);

  String _selectedLang = '';
  String _selectedCountry = CountryInfoService.defaultCountryCode;
  bool _autoDetectCountry = true;
  bool _isResolvingCountry = false;
  bool _countryTouchedByUser = false;
  Locale? _currentLocale;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final lang =
        await _settingsDao.getSettingStr(SettingKeys.languageCode) ?? '';
    final auto =
        await _settingsDao.getSettingBool(SettingKeys.autoGetCountry) ?? true;

    final storedCountryRaw =
        await _settingsDao.getSettingStr(SettingKeys.countryCode);
    final storedCountry =
        CountryInfoService.normalizeCountryCode(storedCountryRaw);

    // Initial instant guess from device locale
    String country = storedCountry;
    if (country.isEmpty) {
      final deviceGuess =
          await CountryInfoService.resolveCountryCodeFromDeviceLocale();
      if (deviceGuess != null && deviceGuess.isNotEmpty) {
        country = deviceGuess;
      } else {
        country = CountryInfoService.defaultCountryCode;
      }
    }

    final supportedCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    final normalizedLang =
        lang.isEmpty || supportedCodes.contains(lang) ? lang : '';

    if (!mounted) return;
    setState(() {
      _selectedLang = normalizedLang;
      _selectedCountry = country;
      _autoDetectCountry = auto;
      _currentLocale = normalizedLang.isEmpty ? null : Locale(normalizedLang);
    });

    if (auto && storedCountry.isEmpty) {
      _triggerAutoDetect();
    }
  }

  Future<void> _triggerAutoDetect() async {
    if (!mounted) return;
    setState(() => _isResolvingCountry = true);
    final code = await CountryInfoService.resolveAndCacheCountryCode(
      settingsDao: _settingsDao,
      forceRefresh: true,
    );
    if (!mounted || _countryTouchedByUser) return;
    setState(() {
      _selectedCountry = code;
      _isResolvingCountry = false;
    });
  }

  void _updateLang(String? val) {
    if (val == null) return;
    setState(() {
      _selectedLang = val;
      _currentLocale = val.isEmpty ? null : Locale(val);
    });
    _settingsDao.putSettingStr(SettingKeys.languageCode, val);
  }

  void _updateCountry(String val) {
    setState(() {
      _countryTouchedByUser = true;
      _selectedCountry = val;
      if (_autoDetectCountry) {
        _autoDetectCountry = false;
        _settingsDao.putSettingBool(SettingKeys.autoGetCountry, false);
      }
    });
    _settingsDao.putSettingStr(SettingKeys.countryCode, val);
  }

  Future<void> _updateAutoDetect(bool val) async {
    setState(() {
      _autoDetectCountry = val;
      if (val) {
        _countryTouchedByUser = false;
      }
    });
    await _settingsDao.putSettingBool(SettingKeys.autoGetCountry, val);

    if (val) {
      await _triggerAutoDetect();
    }
  }

  Future<void> _finish() async {
    await _settingsDao.putSettingBool(
      SettingKeys.autoGetCountry,
      _autoDetectCountry,
    );
    await _settingsDao.putSettingStr(SettingKeys.countryCode, _selectedCountry);
    await _settingsDao.putSettingStr(SettingKeys.languageCode, _selectedLang);
    await OnboardingService.markDone(_settingsDao);
    widget.onComplete();
  }

  List<DropdownMenuItem<String>> _buildLanguageItems(AppLocalizations l10n) {
    final options = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: '',
        child: Text(l10n.countrySettingSystemDefault),
      ),
    ];

    for (final option in buildLanguageOptions()) {
      options.add(
        DropdownMenuItem(
          value: option.code,
          child: Text(option.label),
        ),
      );
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Default_Theme().defaultThemeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _currentLocale,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          if (l10n == null) {
            return const Scaffold(backgroundColor: Default_Theme.themeColor);
          }

          final languageItems = _buildLanguageItems(l10n);

          final selectedCountry = countries.containsValue(_selectedCountry)
              ? _selectedCountry
              : CountryInfoService.defaultCountryCode;

          final textTheme = Theme.of(context).textTheme;

          return Scaffold(
            backgroundColor: Default_Theme.themeColor,
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Default_Theme.themeColor,
                    Default_Theme.themeColor.withValues(alpha: 0.95),
                    const Color(0xFF07040B),
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Default_Theme.primaryColor1
                              .withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                "assets/icons/tarangx_logo.png",
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            l10n.onboardingTitle,
                            style: textTheme.headlineMedium?.copyWith(
                              color: Default_Theme.primaryColor1,
                              fontWeight: FontWeight.w800,
                              fontFamily:
                                  Default_Theme.secondoryTextStyle.fontFamily,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.onboardingSubtitle,
                            style: textTheme.bodyLarge?.copyWith(
                              color: Default_Theme.primaryColor1
                                  .withValues(alpha: 0.75),
                              fontFamily:
                                  Default_Theme.secondoryTextStyle.fontFamily,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          _FieldLabel(label: l10n.countrySettingLanguageLabel),
                          const SizedBox(height: 10),
                          _DropdownField(
                            value: _selectedLang,
                            items: languageItems,
                            onChanged: _updateLang,
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _FieldLabel(
                                  label: l10n.countrySettingAutoDetect,
                                ),
                              ),
                              if (_isResolvingCountry)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Default_Theme.accentColor2,
                                  ),
                                ),
                              if (_isResolvingCountry)
                                const SizedBox(width: 10),
                              _AestheticSwitch(
                                value: _autoDetectCountry,
                                onChanged: _updateAutoDetect,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                CountryPickerModal.show(
                                  context: context,
                                  currentCountryCode: selectedCountry,
                                  onSelected: _updateCountry,
                                  onAutoDetect: () async {
                                    final code =
                                        await CountryInfoService
                                            .resolveAndCacheCountryCode(
                                      settingsDao: _settingsDao,
                                      forceRefresh: true,
                                    );
                                    _updateCountry(code);
                                    return code;
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 15),
                                decoration: BoxDecoration(
                                  color: _OnboardingOverlayState._fieldColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Default_Theme.primaryColor1
                                        .withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (countryCodeToEmoji(selectedCountry)
                                        .isNotEmpty) ...[
                                      Text(
                                        countryCodeToEmoji(selectedCountry),
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Expanded(
                                      child: Text(
                                        '${countries.entries.firstWhere((e) => e.value == selectedCountry, orElse: () => MapEntry(selectedCountry, selectedCountry)).key} ($selectedCountry)',
                                        style: const TextStyle(
                                          color: Default_Theme.primaryColor1,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ).merge(
                                            Default_Theme.secondoryTextStyle),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_isResolvingCountry)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Default_Theme.accentColor2,
                                        ),
                                      )
                                    else
                                      Icon(
                                        MingCute.down_line,
                                        color: Default_Theme.primaryColor1
                                            .withValues(alpha: 0.8),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton(
                            onPressed: _finish,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Default_Theme.accentColor2,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              l10n.continueButton,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Default_Theme.primaryColor1,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ).merge(Default_Theme.secondoryTextStyle),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _OnboardingOverlayState._fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Default_Theme.primaryColor1.withValues(alpha: 0.12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: _OnboardingOverlayState._fieldColor,
          icon: Icon(
            MingCute.down_line,
            color: Default_Theme.primaryColor1.withValues(alpha: 0.8),
          ),
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ).merge(Default_Theme.secondoryTextStyle),
          selectedItemBuilder: (context) {
            return items
                .map(
                  (item) => Align(
                    alignment: Alignment.centerLeft,
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        color: Default_Theme.primaryColor1,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ).merge(Default_Theme.secondoryTextStyle),
                      child: item.child,
                    ),
                  ),
                )
                .toList();
          },
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AestheticSwitch extends StatelessWidget {
  const _AestheticSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 54,
        height: 30,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: value
              ? Default_Theme.accentColor2.withValues(alpha: 0.2)
              : Default_Theme.primaryColor1.withValues(alpha: 0.06),
          border: Border.all(
            color: value
                ? Default_Theme.accentColor2.withValues(alpha: 0.65)
                : Default_Theme.primaryColor1.withValues(alpha: 0.18),
            width: 1.4,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? Default_Theme.accentColor2
                  : Default_Theme.primaryColor1.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
