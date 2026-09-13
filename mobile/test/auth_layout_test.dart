// شاشةُ الدخول على شكل التصميم الذي أرسله صاحبُ المنصّة — ومربّعُ «تذكّرني».
//
// ── وأخطرُ ما يُقاس هنا أنّ المربّع يفعل شيئاً ──────────────────────────────
//
// قيل لصاحب المنصّة إنّ الجلسةَ محفوظةٌ أبداً، وإنّ مربّعاً يُرفع ويُخفض ولا
// يقع شيء **كذبٌ في شاشة**. فاختار الصورةَ كما هي، فوجب أن يصدق المربّع:
//
//   ١) ما يُخفَض يصل الخزنةَ لا الشاشةَ وحدَها.
//   ٢) وأوّلُ إقلاعٍ بعده يبدأ بلا حساب.
//
// **ولا يُسأل المربّعُ عمّا يعرضه:** يُسأل `rememberIsOn()` وتُسأل الجلسةُ
// بعد `boot`.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/remember.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

/// **ولا `pumpAndSettle`:** في الشاشة حقولُ نصّ، ومؤشّرُ الكتابة ينبض فلا
/// تسكن الإطاراتُ أبداً.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _guest() => Session()..loading = false;

const _remember = ValueKey('remember-me');
const _switch = ValueKey('switch-face');

void main() {
  setUp(() => rememberStorageOverride = {});
  tearDown(() => rememberStorageOverride = null);

  group('الشكل', () {
    testWidgets('**رأسٌ أحمرُ وورقةٌ بيضاء**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest())));
      await _settle(tester);

      // الأرضيّةُ حمراءُ والورقةُ تعلوها — وهو الفرقُ الأظهرُ عن القائم.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.accent);
      expect(find.text('دخول الحساب'), findsOneWidget);
      expect(find.text('فرحتي'), findsOneWidget);
    });

    testWidgets('وزرٌّ محاطٌ يقلب الوجه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest())));
      await _settle(tester);

      expect(find.widgetWithText(OutlinedButton, 'إنشاء حساب'), findsOneWidget);
      await tester.tap(find.byKey(_switch));
      await _settle(tester);

      expect(find.text('إنشاء حساب'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'إنشاء الحساب'), findsOneWidget);
    });

    testWidgets('**ولا «تذكّرني» في وجه الإنشاء**', (tester) async {
      // من يُنشئ حساباً لا جلسةَ سابقةً تُذكر، ولا كلمةَ له تُنسى.
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest())));
      await _settle(tester);
      expect(find.byKey(_remember), findsOneWidget);
      expect(find.text('نسيت كلمة المرور'), findsOneWidget);

      await tester.tap(find.byKey(_switch));
      await _settle(tester);
      expect(find.byKey(_remember), findsNothing);
      expect(find.text('نسيت كلمة المرور'), findsNothing);
    });

    testWidgets('والمربّعُ مرفوعٌ ابتداءً', (tester) async {
      // وهو ما يفعله التطبيقُ اليوم — فلا يتبدّل على أحدٍ شيءٌ بلا أن يطلبه.
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest())));
      await _settle(tester);
      expect(tester.widget<Checkbox>(find.byKey(_remember)).value, isTrue);
    });
  });

  group('وما يصل الخزنة', () {
    testWidgets('**ما يُخفَض يصل الخزنةَ لا الشاشةَ وحدَها**', (tester) async {
      _phone(tester);
      final session = _guest();
      await tester.pumpWidget(_wrap(AuthScreen(session: session)));
      await _settle(tester);

      await tester.tap(find.byKey(_remember));
      await _settle(tester);
      expect(tester.widget<Checkbox>(find.byKey(_remember)).value, isFalse);

      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.tap(find.widgetWithText(FilledButton, 'دخول'));
      await _settle(tester);

      // **ولا يُسأل المربّعُ عمّا يعرضه** — الشاشةُ تعرض اختيارَها ولو لم
      // يصل الخزنةَ شيء.
      expect(await rememberIsOn(), isFalse);
    });

    testWidgets('ومن تركه مرفوعاً تبقى جلستُه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(AuthScreen(session: _guest())));
      await _settle(tester);

      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.tap(find.widgetWithText(FilledButton, 'دخول'));
      await _settle(tester);

      expect(await rememberIsOn(), isTrue);
    });
  });

  group('وأوّلُ إقلاعٍ بعده', () {
    test('**من خفضه يبدأ بلا حساب**', () async {
      await setRemember(false);
      final session = Session();
      await session.boot();
      expect(session.userId, isNull);
      expect(session.signedIn, isFalse);
    });

    test('ومن رفعه يبدأ بحسابه', () async {
      await setRemember(true);
      final session = Session();
      await session.boot();
      expect(session.userId, isNotNull);
    });

    test('ومن لم يمرّ على الشاشة قطُّ يبدأ بحسابه', () async {
      // **والافتراضُ نعم** — فلا يُطرد من لم يُسأل.
      rememberStorageOverride = {};
      final session = Session();
      await session.boot();
      expect(session.userId, isNotNull);
    });
  });
}
