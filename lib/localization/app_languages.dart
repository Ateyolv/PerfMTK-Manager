import 'package:flutter_localization/flutter_localization.dart';
import 'package:manager/localization/app_locales.dart';

/// Keep the package's saved selection and normalize unsupported startup locales.
abstract final class AppLanguages {
  static const supported = ['en', 'es', 'zh'];
  static const mapLocales = [
    MapLocale('en', AppLocale.en),
    MapLocale('es', AppLocale.es),
    MapLocale('zh', AppLocale.zh),
  ];

  static String resolve(String localeName) {
    final language = localeName.split(RegExp(r'[_-]')).first.toLowerCase();
    return supported.contains(language) ? language : 'en';
  }

  static void initialize(FlutterLocalization localization, String systemLocale) {
    localization.init(
      mapLocales: mapLocales,
      initLanguageCode: resolve(systemLocale),
    );
    final saved = localization.currentLocale?.languageCode ?? '';
    if (!supported.contains(saved)) {
      localization.translate(resolve(saved), save: false);
    }
  }
}
