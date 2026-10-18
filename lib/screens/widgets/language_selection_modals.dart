import 'dart:ui';
import 'package:Bloomee/core/theme/app_theme.dart';
import 'package:Bloomee/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icons_plus/icons_plus.dart';

/// Item representing a song/music language preference.
class MusicLanguageOption {
  final String id;
  final String name;
  final String native;
  final String description;

  const MusicLanguageOption({
    required this.id,
    required this.name,
    required this.native,
    required this.description,
  });
}

const List<MusicLanguageOption> kAvailableMusicLanguages = [
  MusicLanguageOption(
    id: 'Hindi',
    name: 'Hindi',
    native: 'हिन्दी',
    description: 'Bollywood, Indie Pop, Sufi & Romance',
  ),
  MusicLanguageOption(
    id: 'English',
    name: 'English',
    native: 'English',
    description: 'Global Pop, Hip-Hop, Rock & Electronic',
  ),
  MusicLanguageOption(
    id: 'Punjabi',
    name: 'Punjabi',
    native: 'ਪੰਜਾਬੀ',
    description: 'Bhangra, Desi Hip-Hop, Pop & Folk',
  ),
  MusicLanguageOption(
    id: 'Tamil',
    name: 'Tamil',
    native: 'தமிழ்',
    description: 'Kollywood, Carnatic fusion, Kuthu & Melodies',
  ),
  MusicLanguageOption(
    id: 'Telugu',
    name: 'Telugu',
    native: 'తెలుగు',
    description: 'Tollywood, Mass Beats & Melodies',
  ),
  MusicLanguageOption(
    id: 'Malayalam',
    name: 'Malayalam',
    native: 'മലയാളം',
    description: 'Mollywood indie, soothing vibes & melodies',
  ),
  MusicLanguageOption(
    id: 'Kannada',
    name: 'Kannada',
    native: 'ಕನ್ನಡ',
    description: 'Sandalwood hits, Bhavageethe & Pop',
  ),
  MusicLanguageOption(
    id: 'Bhojpuri',
    name: 'Bhojpuri',
    native: 'भोजपुरी',
    description: 'Folk beats, DJ dhamaka & Chartbusters',
  ),
  MusicLanguageOption(
    id: 'Bengali',
    name: 'Bengali',
    native: 'বাংলা',
    description: 'Rabindra Sangeet, Bangla Pop & Melodies',
  ),
  MusicLanguageOption(
    id: 'Marathi',
    name: 'Marathi',
    native: 'मराठी',
    description: 'Natya sangeet, Lavani & Modern Marathi',
  ),
  MusicLanguageOption(
    id: 'Gujarati',
    name: 'Gujarati',
    native: 'ગુજરાતી',
    description: 'Garba, Sugam Sangeet & Urban Gujarati',
  ),
  MusicLanguageOption(
    id: 'Haryanvi',
    name: 'Haryanvi',
    native: 'हरियाणवी',
    description: 'Ragni, Desi beats & Dance numbers',
  ),
  MusicLanguageOption(
    id: 'Spanish',
    name: 'Spanish',
    native: 'Español',
    description: 'Latin Pop, Reggaeton & Bachata',
  ),
  MusicLanguageOption(
    id: 'Korean',
    name: 'Korean',
    native: '한국어',
    description: 'K-Pop, K-Drama OST & K-Indie',
  ),
  MusicLanguageOption(
    id: 'Japanese',
    name: 'Japanese',
    native: '日本語',
    description: 'J-Pop, City Pop, Anime OST & Rock',
  ),
  MusicLanguageOption(
    id: 'Arabic',
    name: 'Arabic',
    native: 'العربية',
    description: 'Arabic Pop, Khaliji & Levantine beats',
  ),
  MusicLanguageOption(
    id: 'French',
    name: 'French',
    native: 'Français',
    description: 'French Pop, Chanson & Hip-Hop',
  ),
  MusicLanguageOption(
    id: 'German',
    name: 'German',
    native: 'Deutsch',
    description: 'Deutschpop, Schlager & Electronic',
  ),
];

/// Curated playlists data for music languages to ensure immediate rich rendering.
class CuratedLanguagePlaylistData {
  final String id;
  final String title;
  final String language;
  final String subtitle;
  final String coverUrl;
  final String searchQuery;

  const CuratedLanguagePlaylistData({
    required this.id,
    required this.title,
    required this.language,
    required this.subtitle,
    required this.coverUrl,
    required this.searchQuery,
  });
}

const List<CuratedLanguagePlaylistData> kCuratedLanguagePlaylists = [
  // Hindi
  CuratedLanguagePlaylistData(
    id: 'hindi_hot_50',
    title: 'Bollywood Hot 50',
    language: 'Hindi',
    subtitle: 'The hottest tracks ruling the Bollywood charts right now',
    coverUrl:
        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Bollywood Top 50 Hits Playlist',
  ),
  CuratedLanguagePlaylistData(
    id: 'hindi_romance',
    title: 'Hindi Romantic Melodies',
    language: 'Hindi',
    subtitle: 'Soul-stirring love songs and acoustic romantic ballads',
    coverUrl:
        'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Hindi Romance Hits Love Songs Playlist',
  ),
  CuratedLanguagePlaylistData(
    id: 'hindi_90s',
    title: '90s Bollywood Nostalgia',
    language: 'Hindi',
    subtitle: 'Timeless melodies from the golden era of 90s cinema',
    coverUrl:
        'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=80',
    searchQuery: '90s Bollywood Evergreen Songs Playlist',
  ),
  CuratedLanguagePlaylistData(
    id: 'hindi_indie',
    title: 'Indie India Vibes',
    language: 'Hindi',
    subtitle: 'Fresh acoustic sounds from independent Indian artists',
    coverUrl:
        'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Indian Indie Hits Playlist',
  ),

  // English
  CuratedLanguagePlaylistData(
    id: 'english_global_top',
    title: 'Today\'s Top Global Hits',
    language: 'English',
    subtitle: 'The most-played tracks around the globe today',
    coverUrl:
        'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Global Top Hits Playlist',
  ),
  CuratedLanguagePlaylistData(
    id: 'english_chill_pop',
    title: 'Chill Pop & Acoustic',
    language: 'English',
    subtitle: 'Relaxed grooves, mellow vocals, and warm acoustic jams',
    coverUrl:
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Chill Pop Acoustic Vibes Playlist',
  ),
  CuratedLanguagePlaylistData(
    id: 'english_hiphop',
    title: 'Hip-Hop & R&B Anthems',
    language: 'English',
    subtitle: 'Heavy basslines, viral bars, and modern hip-hop bangers',
    coverUrl:
        'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Hip Hop and RnB Hits Playlist',
  ),

  // Punjabi
  CuratedLanguagePlaylistData(
    id: 'punjabi_fire',
    title: 'Punjabi Fire 100',
    language: 'Punjabi',
    subtitle: 'High-energy Bhangra and explosive Punjabi chartbusters',
    coverUrl:
        'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Punjabi Top Hits Playlist',
  ),
  CuratedLanguagePlaylistData(
    id: 'punjabi_swag',
    title: 'Desi Hip-Hop & Swag',
    language: 'Punjabi',
    subtitle: 'Raw trap beats and swagger from northern rap pioneers',
    coverUrl:
        'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Desi Hip Hop Punjabi Trap Playlist',
  ),

  // Tamil
  CuratedLanguagePlaylistData(
    id: 'tamil_top_50',
    title: 'Tamil Top 50',
    language: 'Tamil',
    subtitle: 'Unstoppable Kollywood bangers, mass beats, and top charts',
    coverUrl:
        'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Tamil Top Hits Playlist',
  ),
  CuratedLanguagePlaylistData(
    id: 'tamil_melody',
    title: 'Kollywood Romantic Breeze',
    language: 'Tamil',
    subtitle: 'Soothing Tamil melodies crafted by master composers',
    coverUrl:
        'https://images.unsplash.com/photo-1511735111819-9a3f7709049c?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Tamil Romantic Hits Playlist',
  ),

  // Telugu
  CuratedLanguagePlaylistData(
    id: 'telugu_mega_hits',
    title: 'Tollywood Mega Hits',
    language: 'Telugu',
    subtitle: 'The biggest mass dance numbers and viral Telugu tracks',
    coverUrl:
        'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Telugu Top Hits Playlist',
  ),
  CuratedLanguagePlaylistData(
    id: 'telugu_melodies',
    title: 'Telugu Heartfelt Melodies',
    language: 'Telugu',
    subtitle: 'Sweet vocals and enchanting Telugu romantic chords',
    coverUrl:
        'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Telugu Romantic Songs Playlist',
  ),

  // Malayalam
  CuratedLanguagePlaylistData(
    id: 'malayalam_magic',
    title: 'Mollywood Melodies',
    language: 'Malayalam',
    subtitle: 'Breathtaking acoustics and new-age Kerala indie music',
    coverUrl:
        'https://images.unsplash.com/photo-1511735111819-9a3f7709049c?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Malayalam Top Hits Playlist',
  ),

  // Kannada
  CuratedLanguagePlaylistData(
    id: 'kannada_chartbusters',
    title: 'Chandanavana Chartbusters',
    language: 'Kannada',
    subtitle: 'Trending songs and upbeat Kannada cinematic music',
    coverUrl:
        'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Kannada Top Hits Playlist',
  ),

  // Bhojpuri
  CuratedLanguagePlaylistData(
    id: 'bhojpuri_dhamaka',
    title: 'Bhojpuri Superhits Dhamaka',
    language: 'Bhojpuri',
    subtitle: 'High-voltage folk and dance anthems',
    coverUrl:
        'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Bhojpuri Top Hits Playlist',
  ),

  // Bengali
  CuratedLanguagePlaylistData(
    id: 'bengali_modern',
    title: 'Bangla Modern & Hits',
    language: 'Bengali',
    subtitle: 'Soulful Bengali classics and contemporary melodies',
    coverUrl:
        'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Bengali Top Hits Playlist',
  ),

  // Marathi
  CuratedLanguagePlaylistData(
    id: 'marathi_chartbusters',
    title: 'Marathi Chartbusters',
    language: 'Marathi',
    subtitle: 'Energetic dhol-tasha beats, Ajay-Atul hits & pop',
    coverUrl:
        'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Marathi Top Hits Playlist',
  ),

  // Gujarati
  CuratedLanguagePlaylistData(
    id: 'gujarati_garba_pop',
    title: 'Gujarati Garba & Pop Hits',
    language: 'Gujarati',
    subtitle: 'Traditional Garba vibes and urban Gujarati hits',
    coverUrl:
        'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Gujarati Top Hits Playlist',
  ),

  // Haryanvi
  CuratedLanguagePlaylistData(
    id: 'haryanvi_desi_beats',
    title: 'Desi Haryanvi Swag',
    language: 'Haryanvi',
    subtitle: 'Raw beats, thumping bass, and viral Haryanvi hooks',
    coverUrl:
        'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Haryanvi Top Hits Playlist',
  ),

  // Spanish
  CuratedLanguagePlaylistData(
    id: 'spanish_viva_latino',
    title: 'Viva Latino Fiesta',
    language: 'Spanish',
    subtitle: 'Reggaeton, Bachata, and Spanish urban hits',
    coverUrl:
        'https://images.unsplash.com/photo-1524368535928-5b5e00ddc76b?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Spanish Latin Pop Top Hits Playlist',
  ),

  // Korean
  CuratedLanguagePlaylistData(
    id: 'korean_kpop_daebak',
    title: 'K-Pop Daebak',
    language: 'Korean',
    subtitle: 'The sharpest choreo tracks and idols leading the K-Wave',
    coverUrl:
        'https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'K-Pop Top Hits Playlist',
  ),

  // Japanese
  CuratedLanguagePlaylistData(
    id: 'japanese_jpop_spotlight',
    title: 'J-Pop & Anime Anthems',
    language: 'Japanese',
    subtitle: 'Sensational Japanese chart toppers and iconic anime themes',
    coverUrl:
        'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'J-Pop Anime Top Hits Playlist',
  ),

  // Arabic
  CuratedLanguagePlaylistData(
    id: 'arabic_pop_stars',
    title: 'Arabic Pop Stars',
    language: 'Arabic',
    subtitle: 'Catchy rhythms and Middle Eastern pop anthems',
    coverUrl:
        'https://images.unsplash.com/photo-1447069387593-a5de076249c5?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Arabic Top Hits Playlist',
  ),

  // French
  CuratedLanguagePlaylistData(
    id: 'french_pop_vibes',
    title: 'French Pop & Chill',
    language: 'French',
    subtitle: 'Smooth vocals, French Chanson and indie pop',
    coverUrl:
        'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'French Pop Hits Playlist',
  ),

  // German
  CuratedLanguagePlaylistData(
    id: 'german_deutschpop',
    title: 'Deutschpop Chartstürmer',
    language: 'German',
    subtitle: 'Contemporary German pop, lyrical rap and radio hits',
    coverUrl:
        'https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=500&auto=format&fit=crop&q=80',
    searchQuery: 'Deutschpop Top Hits Playlist',
  ),
];

/// Spotify-style App Language Selector Modal.
class SpotifyLanguageModal {
  SpotifyLanguageModal._();

  static Future<void> show({
    required BuildContext context,
    required String currentCode,
    required ValueChanged<String> onSelected,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final options = [
      (
        code: '',
        native: l10n.countrySettingSystemDefault,
        english: 'Follow device language',
      ),
      (
        code: 'en',
        native: 'English',
        english: 'English',
      ),
      (
        code: 'hi',
        native: 'हिन्दी',
        english: 'Hindi',
      ),
      (
        code: 'es',
        native: 'Español',
        english: 'Spanish',
      ),
      (
        code: 'de',
        native: 'Deutsch',
        english: 'German',
      ),
      (
        code: 'ja',
        native: '日本語',
        english: 'Japanese',
      ),
      (
        code: 'ko',
        native: '한국어',
        english: 'Korean',
      ),
      (
        code: 'zh',
        native: '中文',
        english: 'Chinese',
      ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _SpotifyLanguageSheetContent(
          currentCode: currentCode,
          options: options,
          onSelected: onSelected,
        );
      },
    );
  }
}

class _SpotifyLanguageSheetContent extends StatefulWidget {
  final String currentCode;
  final List<({String code, String native, String english})> options;
  final ValueChanged<String> onSelected;

  const _SpotifyLanguageSheetContent({
    required this.currentCode,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_SpotifyLanguageSheetContent> createState() =>
      _SpotifyLanguageSheetContentState();
}

class _SpotifyLanguageSheetContentState
    extends State<_SpotifyLanguageSheetContent> {
  late final TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((item) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return item.native.toLowerCase().contains(q) ||
          item.english.toLowerCase().contains(q) ||
          item.code.toLowerCase().contains(q);
    }).toList();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Default_Theme.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Default_Theme.surfaceBorderSubtle,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Default_Theme.primaryColor2.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Default_Theme.accentColor2.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        MingCute.translate_2_line,
                        color: Default_Theme.accentLavender,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Language',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Default_Theme.primaryColor1,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select your preferred language for the interface',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Default_Theme.primaryColor2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(MingCute.close_line,
                        color: Default_Theme.primaryColor2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Default_Theme.themeColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Default_Theme.surfaceBorderSubtle,
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _query = val.trim()),
                  style: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    color: Default_Theme.primaryColor1,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search languages...',
                    hintStyle: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 13.5,
                      color:
                          Default_Theme.primaryColor2.withValues(alpha: 0.6),
                    ),
                    prefixIcon: const Icon(
                      MingCute.search_line,
                      size: 18,
                      color: Default_Theme.primaryColor2,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(MingCute.close_circle_fill,
                                size: 16, color: Default_Theme.primaryColor2),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Languages List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final isSelected = widget.currentCode == item.code;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      splashColor:
                          Default_Theme.accentColor2.withValues(alpha: 0.15),
                      highlightColor:
                          Default_Theme.accentColor2.withValues(alpha: 0.08),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onSelected(item.code);
                        Navigator.of(context).pop();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Default_Theme.accentColor2
                                  .withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Default_Theme.accentColor2
                                    .withValues(alpha: 0.4)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.native,
                                    style: TextStyle(
                                      fontFamily: 'Gilroy',
                                      fontSize: 16,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? Default_Theme.accentLavender
                                          : Default_Theme.primaryColor1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.english,
                                    style: TextStyle(
                                      fontFamily: 'Gilroy',
                                      fontSize: 12.5,
                                      color: isSelected
                                          ? Default_Theme.primaryColor1
                                              .withValues(alpha: 0.8)
                                          : Default_Theme.primaryColor2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Spotify-style selection indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isSelected
                                    ? Default_Theme.brandGradient
                                    : null,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : Default_Theme.primaryColor2
                                          .withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Center(
                                      child: Icon(
                                        MingCute.check_fill,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Spotify-style Music / Song Languages Preference Modal Sheet.
class MusicLanguagePickerModal {
  MusicLanguagePickerModal._();

  static Future<void> show({
    required BuildContext context,
    required List<String> currentLanguages,
    required ValueChanged<List<String>> onSaved,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _MusicLanguagePickerSheet(
          initialLanguages: currentLanguages,
          onSaved: onSaved,
        );
      },
    );
  }
}

class _MusicLanguagePickerSheet extends StatefulWidget {
  final List<String> initialLanguages;
  final ValueChanged<List<String>> onSaved;

  const _MusicLanguagePickerSheet({
    required this.initialLanguages,
    required this.onSaved,
  });

  @override
  State<_MusicLanguagePickerSheet> createState() =>
      _MusicLanguagePickerSheetState();
}

class _MusicLanguagePickerSheetState extends State<_MusicLanguagePickerSheet> {
  late final Set<String> _selected;
  late final TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialLanguages.isEmpty
        ? ['Hindi', 'English']
        : widget.initialLanguages);
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(String lang) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(lang)) {
        if (_selected.length > 1) {
          _selected.remove(lang);
        }
      } else {
        _selected.add(lang);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = kAvailableMusicLanguages.where((item) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return item.name.toLowerCase().contains(q) ||
          item.native.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q);
    }).toList();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: Default_Theme.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Default_Theme.surfaceBorderSubtle,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Default_Theme.primaryColor2.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Default_Theme.accentColor2.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        MingCute.music_2_line,
                        color: Default_Theme.accentLavender,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Music Languages',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Default_Theme.primaryColor1,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_selected.length} language${_selected.length == 1 ? '' : 's'} selected',
                          style: const TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Default_Theme.accentLavender,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(MingCute.close_line,
                        color: Default_Theme.primaryColor2),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Default_Theme.themeColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Default_Theme.surfaceBorderSubtle,
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _query = val.trim()),
                  style: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 14,
                    color: Default_Theme.primaryColor1,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search music languages...',
                    hintStyle: TextStyle(
                      fontFamily: 'Gilroy',
                      fontSize: 13.5,
                      color:
                          Default_Theme.primaryColor2.withValues(alpha: 0.6),
                    ),
                    prefixIcon: const Icon(
                      MingCute.search_line,
                      size: 18,
                      color: Default_Theme.primaryColor2,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(MingCute.close_circle_fill,
                                size: 16, color: Default_Theme.primaryColor2),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Your home playlists and recommendations will update automatically to feature music from these languages.',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 12,
                    color: Default_Theme.primaryColor2.withValues(alpha: 0.8),
                    height: 1.35,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Languages Grid / List
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final isSelected = _selected.contains(item.name);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      splashColor:
                          Default_Theme.accentColor2.withValues(alpha: 0.15),
                      highlightColor:
                          Default_Theme.accentColor2.withValues(alpha: 0.08),
                      onTap: () => _toggle(item.name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Default_Theme.accentColor2
                                  .withValues(alpha: 0.14)
                              : Default_Theme.surface.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Default_Theme.accentColor2
                                    .withValues(alpha: 0.5)
                                : Default_Theme.surfaceBorderSubtle,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Checkbox icon
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                gradient: isSelected
                                    ? Default_Theme.brandGradient
                                    : null,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : Default_Theme.primaryColor2
                                          .withValues(alpha: 0.4),
                                  width: 1.4,
                                ),
                              ),
                              child: isSelected
                                  ? const Center(
                                      child: Icon(
                                        MingCute.check_fill,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.native,
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Default_Theme.accentLavender
                                              : Default_Theme.primaryColor1,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${item.name})',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Default_Theme.primaryColor2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Gilroy',
                                      fontSize: 11.5,
                                      color: Default_Theme.primaryColor2
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: Default_Theme.themeColor.withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(
                    color: Default_Theme.surfaceBorderSubtle,
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selected
                          ..clear()
                          ..addAll(['Hindi', 'English']);
                      });
                    },
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Default_Theme.primaryColor2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: Default_Theme.brandGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Default_Theme.accentColor2
                              .withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onSaved(_selected.toList());
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Save & Update Playlists',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
