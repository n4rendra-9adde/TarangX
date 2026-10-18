import 'package:Bloomee/core/theme/app_theme.dart';
import 'package:Bloomee/screens/screen/home_views/setting_views/country_setting.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

String countryCodeToEmoji(String code) {
  if (code.length != 2) return '';
  final upper = code.toUpperCase();
  final first = upper.codeUnitAt(0);
  final second = upper.codeUnitAt(1);
  if (first < 65 || first > 90 || second < 65 || second > 90) return '';
  return String.fromCharCode(first + 127397) +
      String.fromCharCode(second + 127397);
}

class CountryPickerModal extends StatefulWidget {
  final String currentCountryCode;
  final ValueChanged<String> onSelected;
  final Future<String?> Function()? onAutoDetect;

  const CountryPickerModal({
    super.key,
    required this.currentCountryCode,
    required this.onSelected,
    this.onAutoDetect,
  });

  static Future<void> show({
    required BuildContext context,
    required String currentCountryCode,
    required ValueChanged<String> onSelected,
    Future<String?> Function()? onAutoDetect,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountryPickerModal(
        currentCountryCode: currentCountryCode,
        onSelected: onSelected,
        onAutoDetect: onAutoDetect,
      ),
    );
  }

  @override
  State<CountryPickerModal> createState() => _CountryPickerModalState();
}

class _CountryEntry {
  final String name;
  final String code;
  final String flag;
  final String searchKey;

  const _CountryEntry({
    required this.name,
    required this.code,
    required this.flag,
    required this.searchKey,
  });
}

List<_CountryEntry>? _cachedCountryList;

List<_CountryEntry> _getSortedCountryList() {
  if (_cachedCountryList != null) return _cachedCountryList!;
  final list = countries.entries.map((e) {
    final flag = countryCodeToEmoji(e.value);
    return _CountryEntry(
      name: e.key,
      code: e.value,
      flag: flag,
      searchKey: '${e.key.toLowerCase()} ${e.value.toLowerCase()}',
    );
  }).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return _cachedCountryList = List.unmodifiable(list);
}

class _CountryPickerModalState extends State<CountryPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  late final List<_CountryEntry> _allCountries;
  List<_CountryEntry> _filteredCountries = const [];
  bool _isAutoDetecting = false;

  @override
  void initState() {
    super.initState();
    _allCountries = _getSortedCountryList();
    _filteredCountries = _allCountries;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = _allCountries;
      } else {
        _filteredCountries = _allCountries
            .where((entry) => entry.searchKey.contains(query))
            .toList();
      }
    });
  }

  Future<void> _handleAutoDetect() async {
    if (widget.onAutoDetect == null) return;
    setState(() => _isAutoDetecting = true);
    try {
      final detected = await widget.onAutoDetect!();
      if (mounted && detected != null && detected.isNotEmpty) {
        widget.onSelected(detected);
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isAutoDetecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.75;
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Container(
      height: sheetHeight + bottomInset,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: AppTheme.primaryColor1.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor2.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Country',
                  style: TextStyle(
                    color: AppTheme.primaryColor1,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.primaryColor2,
                    size: 22,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor1.withValues(alpha: 0.08),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  color: AppTheme.primaryColor1,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: AppTheme.accentColor2,
                decoration: InputDecoration(
                  hintText: 'Search by country or code...',
                  hintStyle: TextStyle(
                    color: AppTheme.primaryColor2.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    MingCute.search_2_line,
                    color: AppTheme.primaryColor2,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          color: AppTheme.primaryColor2,
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Auto-detect tile if available
          if (widget.onAutoDetect != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isAutoDetecting ? null : _handleAutoDetect,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor2.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.accentColor2.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        _isAutoDetecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.accentColor2,
                                ),
                              )
                            : const Icon(
                                MingCute.location_line,
                                color: AppTheme.accentColor2,
                                size: 20,
                              ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Auto-detect from network / device',
                            style: TextStyle(
                              color: AppTheme.primaryColor1,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppTheme.accentColor2,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 6),

          // Virtualized country list with fixed item extent for instant rendering
          Expanded(
            child: _filteredCountries.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',
                      style: TextStyle(
                        color: AppTheme.primaryColor2.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: _filteredCountries.length,
                    itemExtent: 52.0, // Fixed extent = O(1) layout, 0ms lag
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final entry = _filteredCountries[index];
                      final name = entry.name;
                      final code = entry.code;
                      final isSelected =
                          code.toUpperCase() ==
                              widget.currentCountryCode.toUpperCase();
                      final flag = entry.flag;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onSelected(code);
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.accentColor2.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                if (flag.isNotEmpty) ...[
                                  Text(
                                    flag,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppTheme.accentColor1light
                                          : AppTheme.primaryColor1,
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.accentColor2
                                            .withValues(alpha: 0.25)
                                        : AppTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    code,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppTheme.accentColor2
                                          : AppTheme.primaryColor2,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.accentColor2,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
