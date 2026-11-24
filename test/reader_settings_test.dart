import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/services/preferences_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  test('reader settings are kept per series', () async {
    expect(PreferencesService.getReaderSeriesSettings('a').readingMode, isNull);
    expect(PreferencesService.getReaderSeriesSettings('a').brightness, 1.0);

    await PreferencesService.saveReaderSeriesSettings(
      'a',
      const ReaderSeriesSettings(readingMode: 'webtoon', theme: 'vintage', brightness: 0.5),
    );
    await PreferencesService.saveReaderSeriesSettings('b', const ReaderSeriesSettings(readingMode: 'rtl'));

    final a = PreferencesService.getReaderSeriesSettings('a');
    expect(a.readingMode, 'webtoon');
    expect(a.theme, 'vintage');
    expect(a.brightness, 0.5);
    final b = PreferencesService.getReaderSeriesSettings('b');
    expect(b.readingMode, 'rtl');
    expect(b.theme, isNull);
    expect(b.brightness, 1.0);
  });

  test('copyWith keeps unchanged fields and brightness is clamped when read', () async {
    const base = ReaderSeriesSettings(readingMode: 'ltr', theme: 'night', brightness: 0.8);
    final next = base.copyWith(brightness: 0.4);
    expect(next.readingMode, 'ltr');
    expect(next.theme, 'night');
    expect(next.brightness, 0.4);

    expect(ReaderSeriesSettings.fromJson({'brightness': 0.01}).brightness, 0.2);
  });

  test('auto next chapter defaults on and can be turned off', () async {
    expect(PreferencesService.getAutoNextChapter(), isTrue);
    await PreferencesService.setAutoNextChapter(false);
    expect(PreferencesService.getAutoNextChapter(), isFalse);
  });
}
