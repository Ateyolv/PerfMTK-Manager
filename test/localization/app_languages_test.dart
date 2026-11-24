import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manager/localization/app_languages.dart';
import 'package:manager/presentation/widgets/language_selection_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final localization = FlutterLocalization.instance;
  setUp(() async {
    localization.onTranslatedLanguage = null;
    SharedPreferences.setMockInitialValues({});
    await localization.ensureInitialized();
  });
  tearDown(() { localization.onTranslatedLanguage = null; });

  test('normalizes supported locales and falls back to English', () {
    for (final locale in ['zh_CN', 'zh-Hans-CN', 'zh_Hant_TW', 'ZH-CN']) {
      expect(AppLanguages.resolve(locale), 'zh');
    }
    expect(AppLanguages.resolve('es-ES'), 'es');
    expect(AppLanguages.resolve('en_US'), 'en');
    expect(AppLanguages.resolve('fr_FR'), 'en');
    expect(AppLanguages.resolve(''), 'en');
  });

  test('first launch follows supported system language', () {
    AppLanguages.initialize(localization, 'zh_CN');
    expect(localization.currentLocale?.languageCode, 'zh');
    expect(localization.supportedLanguageCodes, ['en', 'es', 'zh']);
    AppLanguages.initialize(localization, 'fr_FR');
    expect(localization.currentLocale?.languageCode, 'en');
  });

  test('unsupported saved language falls back without breaking delegates', () async {
    SharedPreferences.setMockInitialValues({
      'translator_locale_key': jsonEncode({
        'translator_language_code': 'fr',
        'translator_country_code': 'FR',
        'translator_script_code': null,
      }),
    });
    await localization.ensureInitialized();
    AppLanguages.initialize(localization, 'zh_CN');
    expect(localization.currentLocale?.languageCode, 'en');
  });

  testWidgets('selects Chinese, displays translations, and retains it on restart', (tester) async {
    AppLanguages.initialize(localization, 'en_US');
    await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
      return MaterialApp(
        locale: localization.currentLocale,
        supportedLocales: localization.supportedLocales,
        localizationsDelegates: localization.localizationsDelegates,
        home: Scaffold(body: LanguageSelectionSheet(
          currentLanguage: localization.currentLocale!.languageCode,
          onLanguageSelected: (code) {
            localization.translate(code);
            setState(() {});
          },
        )),
      );
    }));
    await tester.pumpAndSettle();
    expect(find.text('Select Language'), findsOneWidget);
    await tester.tap(find.text('简体中文').first);
    await tester.pumpAndSettle();
    expect(localization.currentLocale?.languageCode, 'zh');
    expect(find.text('选择语言'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Re-run the real package initialization against its persisted preference.
    await tester.pumpWidget(const SizedBox());
    await localization.ensureInitialized();
    AppLanguages.initialize(localization, 'es_ES');
    expect(localization.currentLocale?.languageCode, 'zh');
  });
}
