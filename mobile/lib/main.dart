import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/core/app_lock.dart';
import 'src/core/format.dart';
import 'src/core/i18n.dart';
import 'src/core/session.dart';
import 'src/core/theme.dart';
import 'src/data/supabase.dart';
import 'src/screens/root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFormatting();
  await loadLocale();
  await initSupabase();
  final session = Session();
  await session.boot();
  await appLock.boot();
  runApp(ArasApp(session: session));
}

class ArasApp extends StatelessWidget {
  const ArasApp({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    // **والاستماعُ في الجذر لا في شاشة.** تبديلُ اللغة يقلب اتّجاه الشجرة
    // كلِّها، فيُعاد بناؤها من فوق — ولو استمعت كلُّ شاشةٍ وحدها لَبقيت
    // شاشاتٌ مفتوحةٌ على لغةٍ وشاشاتٌ على أخرى.
    return ValueListenableBuilder<AppLocale>(
      valueListenable: appLocale,
      builder: (context, value, _) => MaterialApp(
        title: 'فرحتي',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // الاتّجاه يتبع اللغة: العربيّة من اليمين والإنجليزيّة من اليسار،
        // وMaterialApp يقلب الشجرة كلَّها تبعاً لـ`locale` — فلا `Directionality`
        // تُكتب بيدٍ في شاشة.
        locale: localeOf(value),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RootScreen(session: session, lock: appLock),
      ),
    );
  }
}
