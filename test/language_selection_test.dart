import 'package:flutter_test/flutter_test.dart';
import 'package:Bloomee/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:Bloomee/screens/widgets/language_selection_modals.dart';

void main() {
  group('SettingsState Language Selection', () {
    test('SettingsInitial defaults to Hindi and English music languages', () {
      final initial = SettingsInitial();
      expect(initial.musicLanguages, containsAll(['Hindi', 'English']));
      expect(initial.languageCode, isEmpty);
    });

    test('copyWith updates musicLanguages and languageCode correctly', () {
      final state = SettingsInitial();
      final updated = state.copyWith(
        musicLanguages: ['Punjabi', 'Spanish', 'Korean'],
        languageCode: 'hi',
      );

      expect(updated.musicLanguages, ['Punjabi', 'Spanish', 'Korean']);
      expect(updated.languageCode, 'hi');
      // Verify immutability
      expect(state.musicLanguages, ['Hindi', 'English']);
    });
  });

  group('Language Selection Data Models', () {
    test('kAvailableMusicLanguages includes key Indian and global languages', () {
      final names = kAvailableMusicLanguages.map((l) => l.name).toSet();
      expect(names, contains('Hindi'));
      expect(names, contains('English'));
      expect(names, contains('Punjabi'));
      expect(names, contains('Tamil'));
      expect(names, contains('Telugu'));
      expect(names, contains('Bhojpuri'));
      expect(names, contains('Spanish'));
      expect(names, contains('Korean'));
      expect(names, contains('Japanese'));
    });

    test('kCuratedLanguagePlaylists contains valid entries for languages', () {
      expect(kCuratedLanguagePlaylists, isNotEmpty);
      for (final playlist in kCuratedLanguagePlaylists) {
        expect(playlist.id, isNotEmpty);
        expect(playlist.title, isNotEmpty);
        expect(playlist.language, isNotEmpty);
        expect(playlist.searchQuery, isNotEmpty);
        expect(playlist.coverUrl, startsWith('http'));
      }
    });

    test('Language playlist filtering logic filters by active selection', () {
      final selectedLanguages = ['Hindi', 'Punjabi'];

      // When tab is 'All', only playlists in selected languages appear
      final allVisible = kCuratedLanguagePlaylists.where((p) {
        return selectedLanguages.contains(p.language);
      }).toList();

      expect(allVisible, isNotEmpty);
      expect(allVisible.every((p) => selectedLanguages.contains(p.language)), isTrue);
      expect(allVisible.any((p) => p.language == 'Hindi'), isTrue);
      expect(allVisible.any((p) => p.language == 'Punjabi'), isTrue);
      expect(allVisible.any((p) => p.language == 'Spanish'), isFalse);

      // When tab is 'Punjabi', only Punjabi playlists appear
      const activeTab = 'Punjabi';
      final punjabiVisible = kCuratedLanguagePlaylists.where((p) {
        return p.language == activeTab;
      }).toList();

      expect(punjabiVisible, isNotEmpty);
      expect(punjabiVisible.every((p) => p.language == 'Punjabi'), isTrue);
    });
  });
}
