import 'package:Bloomee/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:Bloomee/l10n/language_options.dart';
import 'package:Bloomee/screens/screen/home_views/setting_views/setting_shared_widgets.dart';
import 'package:Bloomee/screens/widgets/country_picker_modal.dart';
import 'package:Bloomee/screens/widgets/language_selection_modals.dart';
import 'package:Bloomee/services/db/dao/settings_dao.dart';
import 'package:Bloomee/services/db/db_provider.dart';
import 'package:Bloomee/utils/country_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Bloomee/core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:Bloomee/l10n/app_localizations.dart';
import 'package:icons_plus/icons_plus.dart';

class CountrySettings extends StatelessWidget {
  const CountrySettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageItems = <SettingDropdownItem<String>>[
      SettingDropdownItem<String>(
          value: '', label: l10n.countrySettingSystemDefault),
      ...buildLanguageOptions().map(
        (option) => SettingDropdownItem<String>(
          value: option.code,
          label: option.label,
        ),
      ),
    ];
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Default_Theme.themeColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Default_Theme.primaryColor1),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.countrySettingTitle,
          style: const TextStyle(
            color: Default_Theme.primaryColor1,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ).merge(Default_Theme.secondoryTextStyle),
        ),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (prev, curr) =>
            prev.countryCode != curr.countryCode ||
            prev.autoGetCountry != curr.autoGetCountry ||
            prev.languageCode != curr.languageCode ||
            prev.musicLanguages != curr.musicLanguages,
        builder: (context, state) {
          final currentLanguageLabel = languageItems
              .firstWhere(
                (item) => item.value == state.languageCode,
                orElse: () => languageItems.first,
              )
              .label;

          // Build country name from current code
          final currentCountryName = countries.entries
              .firstWhere(
                (e) => e.value == state.countryCode,
                orElse: () => const MapEntry('Unknown', ''),
              )
              .key;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              SettingSectionHeader(label: l10n.settingsLanguageCountry),
              SettingCard(
                children: [
                  SettingNavTile(
                    icon: MingCute.translate_2_line,
                    title: l10n.countrySettingLanguageLabel,
                    subtitle: currentLanguageLabel,
                    badge: state.languageCode.isEmpty
                        ? 'AUTO'
                        : state.languageCode.toUpperCase(),
                    onTap: () {
                      SpotifyLanguageModal.show(
                        context: context,
                        currentCode: state.languageCode,
                        onSelected: (newValue) {
                          context
                              .read<SettingsCubit>()
                              .setLanguageCode(newValue);
                        },
                      );
                    },
                  ),
                  const SettingDivider(),
                  SettingToggleTile(
                    icon: MingCute.location_line,
                    title: l10n.countrySettingAutoDetect,
                    subtitle: l10n.countrySettingAutoDetectSubtitle,
                    value: state.autoGetCountry,
                    onChanged: (value) async {
                      context.read<SettingsCubit>().setAutoGetCountry(value);
                      if (value) {
                        final code = await CountryInfoService
                            .resolveAndCacheCountryCode(
                          settingsDao: SettingsDAO(DBProvider.db),
                          forceRefresh: true,
                        );
                        if (code.isNotEmpty) {
                          context.read<SettingsCubit>().setCountryCode(code);
                        }
                      }
                    },
                  ),
                  const SettingDivider(),
                  SettingNavTile(
                    icon: MingCute.globe_line,
                    title: l10n.countrySettingCountryLabel,
                    subtitle: currentCountryName,
                    badge: state.countryCode,
                    onTap: () {
                      CountryPickerModal.show(
                        context: context,
                        currentCountryCode: state.countryCode,
                        onSelected: (newCode) {
                          context
                              .read<SettingsCubit>()
                              .setCountryCode(newCode);
                        },
                        onAutoDetect: () async {
                          final code = await CountryInfoService
                              .resolveAndCacheCountryCode(
                            settingsDao: SettingsDAO(DBProvider.db),
                            forceRefresh: true,
                          );
                          if (code.isNotEmpty) {
                            context
                                .read<SettingsCubit>()
                                .setCountryCode(code);
                            return code;
                          }
                          return null;
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SettingSectionHeader(label: 'Music Languages Preference'),
              SettingCard(
                children: [
                  SettingNavTile(
                    icon: MingCute.music_2_line,
                    title: 'Song Languages',
                    subtitle: state.musicLanguages.isEmpty
                        ? 'Hindi, English'
                        : state.musicLanguages.join(', '),
                    badge: '${state.musicLanguages.length} selected',
                    onTap: () {
                      MusicLanguagePickerModal.show(
                        context: context,
                        currentLanguages: state.musicLanguages,
                        onSaved: (langs) {
                          context
                              .read<SettingsCubit>()
                              .setMusicLanguages(langs);
                        },
                      );
                    },
                  ),
                  const SettingDivider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tap to toggle your favorite song languages',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Default_Theme.primaryColor2
                                .withValues(alpha: 0.75),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: kAvailableMusicLanguages.map((item) {
                            final isSelected =
                                state.musicLanguages.contains(item.name);
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  final current =
                                      List<String>.from(state.musicLanguages);
                                  if (isSelected) {
                                    if (current.length > 1) {
                                      current.remove(item.name);
                                    }
                                  } else {
                                    current.add(item.name);
                                  }
                                  context
                                      .read<SettingsCubit>()
                                      .setMusicLanguages(current);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6.5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Default_Theme.accentColor2
                                            .withValues(alpha: 0.16)
                                        : Default_Theme.surface
                                            .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Default_Theme.accentColor2
                                              .withValues(alpha: 0.6)
                                          : Default_Theme.surfaceBorderSubtle,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected) ...[
                                        const Icon(
                                          MingCute.check_fill,
                                          size: 13,
                                          color: Default_Theme.accentLavender,
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(
                                        '${item.native} (${item.name})',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          fontSize: 12.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Default_Theme.accentLavender
                                              : Default_Theme.primaryColor1
                                                  .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

final Map<String, String> countries = {
  'Afghanistan': 'AF',
  'Albania': 'AL',
  'Algeria': 'DZ',
  'Andorra': 'AD',
  'Angola': 'AO',
  'Antigua and Barbuda': 'AG',
  'Argentina': 'AR',
  'Armenia': 'AM',
  'Australia': 'AU',
  'Austria': 'AT',
  'Azerbaijan': 'AZ',
  'Bahamas': 'BS',
  'Bahrain': 'BH',
  'Bangladesh': 'BD',
  'Barbados': 'BB',
  'Belarus': 'BY',
  'Belgium': 'BE',
  'Belize': 'BZ',
  'Benin': 'BJ',
  'Bhutan': 'BT',
  'Bolivia': 'BO',
  'Bosnia and Herzegovina': 'BA',
  'Botswana': 'BW',
  'Brazil': 'BR',
  'Brunei': 'BN',
  'Bulgaria': 'BG',
  'Burkina Faso': 'BF',
  'Burundi': 'BI',
  'Cabo Verde': 'CV',
  'Cambodia': 'KH',
  'Cameroon': 'CM',
  'Canada': 'CA',
  'Central African Republic': 'CF',
  'Chad': 'TD',
  'Chile': 'CL',
  'China': 'CN',
  'Colombia': 'CO',
  'Comoros': 'KM',
  'Congo': 'CG',
  'Costa Rica': 'CR',
  'Croatia': 'HR',
  'Cuba': 'CU',
  'Cyprus': 'CY',
  'Czechia': 'CZ',
  'Denmark': 'DK',
  'Djibouti': 'DJ',
  'Dominica': 'DM',
  'Dominican Republic': 'DO',
  'Ecuador': 'EC',
  'Egypt': 'EG',
  'El Salvador': 'SV',
  'Equatorial Guinea': 'GQ',
  'Eritrea': 'ER',
  'Estonia': 'EE',
  'Eswatini': 'SZ',
  'Ethiopia': 'ET',
  'Fiji': 'FJ',
  'Finland': 'FI',
  'France': 'FR',
  'Gabon': 'GA',
  'Gambia': 'GM',
  'Georgia': 'GE',
  'Germany': 'DE',
  'Ghana': 'GH',
  'Greece': 'GR',
  'Grenada': 'GD',
  'Guatemala': 'GT',
  'Guinea': 'GN',
  'Guinea-Bissau': 'GW',
  'Guyana': 'GY',
  'Haiti': 'HT',
  'Honduras': 'HN',
  'Hungary': 'HU',
  'Iceland': 'IS',
  'India': 'IN',
  'Indonesia': 'ID',
  'Iran': 'IR',
  'Iraq': 'IQ',
  'Ireland': 'IE',
  'Israel': 'IL',
  'Italy': 'IT',
  'Jamaica': 'JM',
  'Japan': 'JP',
  'Jordan': 'JO',
  'Kazakhstan': 'KZ',
  'Kenya': 'KE',
  'Kiribati': 'KI',
  'Korea, North': 'KP',
  'Korea, South': 'KR',
  'Kosovo': 'XK',
  'Kuwait': 'KW',
  'Kyrgyzstan': 'KG',
  'Laos': 'LA',
  'Latvia': 'LV',
  'Lebanon': 'LB',
  'Lesotho': 'LS',
  'Liberia': 'LR',
  'Libya': 'LY',
  'Liechtenstein': 'LI',
  'Lithuania': 'LT',
  'Luxembourg': 'LU',
  'Madagascar': 'MG',
  'Malawi': 'MW',
  'Malaysia': 'MY',
  'Maldives': 'MV',
  'Mali': 'ML',
  'Malta': 'MT',
  'Marshall Islands': 'MH',
  'Mauritania': 'MR',
  'Mauritius': 'MU',
  'Mexico': 'MX',
  'Micronesia': 'FM',
  'Moldova': 'MD',
  'Monaco': 'MC',
  'Mongolia': 'MN',
  'Montenegro': 'ME',
  'Morocco': 'MA',
  'Mozambique': 'MZ',
  'Myanmar': 'MM',
  'Namibia': 'NA',
  'Nauru': 'NR',
  'Nepal': 'NP',
  'Netherlands': 'NL',
  'New Zealand': 'NZ',
  'Nicaragua': 'NI',
  'Niger': 'NE',
  'Nigeria': 'NG',
  'North Macedonia': 'MK',
  'Norway': 'NO',
  'Oman': 'OM',
  'Pakistan': 'PK',
  'Palau': 'PW',
  'Palestine': 'PS',
  'Panama': 'PA',
  'Papua New Guinea': 'PG',
  'Paraguay': 'PY',
  'Peru': 'PE',
  'Philippines': 'PH',
  'Poland': 'PL',
  'Portugal': 'PT',
  'Qatar': 'QA',
  'Romania': 'RO',
  'Russia': 'RU',
  'Rwanda': 'RW',
  'Saint Kitts and Nevis': 'KN',
  'Saint Lucia': 'LC',
  'Saint Vincent and the Grenadines': 'VC',
  'Samoa': 'WS',
  'San Marino': 'SM',
  'Sao Tome and Principe': 'ST',
  'Saudi Arabia': 'SA',
  'Senegal': 'SN',
  'Serbia': 'RS',
  'Seychelles': 'SC',
  'Sierra Leone': 'SL',
  'Singapore': 'SG',
  'Slovakia': 'SK',
  'Slovenia': 'SI',
  'Solomon Islands': 'SB',
  'Somalia': 'SO',
  'South Africa': 'ZA',
  'South Sudan': 'SS',
  'Spain': 'ES',
  'Sri Lanka': 'LK',
  'Sudan': 'SD',
  'Suriname': 'SR',
  'Sweden': 'SE',
  'Switzerland': 'CH',
  'Syria': 'SY',
  'Taiwan': 'TW',
  'Tajikistan': 'TJ',
  'Tanzania': 'TZ',
  'Thailand': 'TH',
  'Timor-Leste': 'TL',
  'Togo': 'TG',
  'Tonga': 'TO',
  'Trinidad and Tobago': 'TT',
  'Tunisia': 'TN',
  'Turkey': 'TR',
  'Turkmenistan': 'TM',
  'Tuvalu': 'TV',
  'Uganda': 'UG',
  'Ukraine': 'UA',
  'United Arab Emirates': 'AE',
  'United Kingdom': 'GB',
  'United States': 'US',
  'Uruguay': 'UY',
  'Uzbekistan': 'UZ',
  'Vanuatu': 'VU',
  'Vatican City': 'VA',
  'Venezuela': 'VE',
  'Vietnam': 'VN',
  'Yemen': 'YE',
  'Zambia': 'ZM',
  'Zimbabwe': 'ZW',
  // Add more countries and their ISO alpha-2 codes here
};
