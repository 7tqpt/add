import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/core/format.dart';
import 'src/core/session.dart';
import 'src/core/theme.dart';
import 'src/data/supabase.dart';
import 'src/screens/root.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFormatting();
  await initSupabase();
  final session = Session();
  await session.boot();
  runApp(ArasApp(session: session));
}

class ArasApp extends StatelessWidget {
  const ArasApp({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فرحتي',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // العربية لغةً وحيدة، والاتجاه يميني في كل الشجرة تبعاً لها — فلا حاجة
      // إلى قلبٍ يدوي في كل شاشة كما في React Native.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RootScreen(session: session),
    );
  }
}
