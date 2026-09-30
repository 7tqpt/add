// «تأكيد رقمك» على صورتي صاحب المنصّة — واختار في ثلاثة أسئلة «أ أ أ»:
//
//   (أ) **الرقمُ كاملاً لا مخفيّاً** — الشاشةُ ليرى صاحبُه أنّه كتبه صحيحاً.
//   (أ) **شعارُ واتساب نفسُه بلونه الأخضر** — لا رمزٌ يشبهه ولا بلوننا.
//   (أ) **«رمز التأكيد» داخلَ الخانة** بلا شُرَط.
//
// **وما يُقاس ما يُرى**: الرقمُ المكتوب بخاناته كلِّها، ولونُ الشعار ومساره،
// وموضعُ العنوان من الخانة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/phone.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/onboarding.dart' show YemenFlag;
import 'package:aras/src/screens/verify_phone.dart';
import 'package:aras/src/ui/auth_frame.dart';
import 'package:aras/src/ui/whatsapp_mark.dart';

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

Session _session([String phone = '+967781447184']) => Session()
  ..userId = 'u1'
  ..appUserId = 'demo-user'
  ..loading = false
  ..phoneGate = PhoneGate(required_: true, verified: false, phone: phone);

/// **ولا `pumpAndSettle`:** مؤشّرُ الكتابة ينبض فلا تسكن الإطارات.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _open(WidgetTester tester, [String phone = '+967781447184']) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(VerifyPhoneScreen(session: _session(phone))));
  await _settle(tester);
}

/// يُهدم الشاشةَ قبل الخروج — فيها مؤقّتُ «أعد الإرسال».
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUp(resetDemoPhoneGate);
  tearDown(resetDemoPhoneGate);

  group('الإطار', () {
    testWidgets('**في إطار شاشات الباب، و«تأكيد رقمك» في الرأس**', (tester) async {
      await _open(tester);
      final frame = tester.widget<AuthFrame>(find.byType(AuthFrame));
      expect(frame.compact && frame.crowned, isTrue);
      final title = tester.getRect(find.text('تأكيد رقمك'));
      final card = tester.getRect(find.byKey(const ValueKey('auth-card')));
      expect(title.bottom, lessThanOrEqualTo(card.top), reason: 'العنوانُ ليس في الرأس');
      expect(find.text('رقمك يؤكَّد مرّةً واحدة'), findsOneWidget);
      expect(find.text('سنرسل رمزاً إلى واتساب لتأكيد رقمك'), findsOneWidget);
      expect(find.text('نستخدم رقمك لتأكيد حجوزاتك والتواصل معك فقط'), findsOneWidget);
    });

    testWidgets('وبعد الإرسال: «أدخل رمز التأكيد»', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('otp-action')));
      await _settle(tester);
      expect(find.text('أدخل رمز التأكيد'), findsOneWidget);
      expect(find.text('أرسلنا رمزاً إلى واتساب على رقمك'), findsOneWidget);
      await _close(tester);
    });
  });

  group('(أ) الرقمُ كاملاً', () {
    testWidgets('**يُكتب بخاناته كلِّها — لا نقطةَ مكانَ رقم**', (tester) async {
      await _open(tester);
      final shown = tester.widget<Text>(find.byKey(const ValueKey('otp-phone'))).data!;
      expect(shown, '+967 781 447 184');
      expect(shown.contains('•'), isFalse, reason: 'خاناتٌ مخفيّة');
      expect(find.byType(YemenFlag), findsOneWidget);
    });

    testWidgets('**وعلمُ اليمن لرقمٍ يمنيٍّ وحده**', (tester) async {
      await _open(tester, '+201012345678');
      expect(find.byType(YemenFlag), findsNothing, reason: 'علمُ اليمن على رقمٍ مصريّ');
      expect(find.text('+201012345678'), findsOneWidget);
    });

    test('ويُقسم ليُقرأ', () {
      expect(displayPhone('+967781447184'), '+967 781 447 184');
      expect(displayPhone('0781447184'), '+967 781 447 184');
      expect(displayPhone('+966512345678'), '+966 512 345 678');
      expect(displayPhone('+201012345678'), '+201012345678');
      expect(displayPhone('abc'), 'abc');
    });
  });

  group('(أ) شعارُ واتساب بلونه', () {
    testWidgets('**فوق العنوان وعلى الزرّ — أخضر**', (tester) async {
      await _open(tester);
      final badge = find.descendant(
        of: find.byKey(const ValueKey('whatsapp-badge')),
        matching: find.byType(WhatsAppMark),
      );
      final button = find.descendant(
        of: find.byKey(const ValueKey('otp-action')),
        matching: find.byType(WhatsAppMark),
      );
      for (final f in [badge, button]) {
        expect(f, findsOneWidget);
        expect(tester.widget<WhatsAppMark>(f).color, whatsappGreen);
      }
      // **وعلى الزرّ في دائرةٍ بيضاء** — الأخضرُ على النبيذيّ مباشرةً يغيم.
      final disc = tester.widget<Container>(find.byKey(const ValueKey('send-whatsapp-mark')));
      expect((disc.decoration! as BoxDecoration).color, Colors.white);
    });

    test('**والمسارُ هو الشعار: حلقةٌ مفرغةٌ وسمّاعةٌ فيها**', () {
      final p = whatsappPath();
      final b = p.getBounds();
      expect(b.left, closeTo(0, 0.1));
      expect(b.top, closeTo(0, 0.1));
      expect(b.right, closeTo(24, 0.1));
      expect(b.bottom, closeTo(24, 0.1));
      expect(p.contains(const Offset(12, 1)), isTrue, reason: 'لا حلقةَ في أعلاه');
      expect(p.contains(const Offset(12, 12)), isFalse, reason: 'الحلقةُ مصمتة — ضاع الفراغ');
      expect(p.contains(const Offset(16.5, 15)), isTrue, reason: 'لا سمّاعة');
    });
  });

  group('(أ) «رمز التأكيد» داخلَ الخانة', () {
    testWidgets('**والعنوانُ في وسط الخانة وهي فارغة — بلا شُرَط**', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('otp-action')));
      await _settle(tester);

      final field = find.byKey(const ValueKey('otp-field'));
      final label = find.descendant(of: field, matching: find.text('رمز التأكيد'));
      final box = tester.getRect(field);
      final at = (tester.getCenter(label).dy - box.top) / box.height;
      expect(at, inInclusiveRange(0.3, 0.7), reason: 'العنوانُ فوق الخانة لا داخلَها');
      expect(find.text('----'), findsNothing);
      await _close(tester);
    });
  });

  testWidgets('ولا يفيض بخطّ الجهاز الكبير — ولا على جوالٍ صغير', (tester) async {
    for (final scale in [1.0, 1.3, 2.0]) {
      tester.view.physicalSize = const Size(960, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(MediaQuery(
        data: MediaQueryData(size: const Size(320, 640), textScaler: TextScaler.linear(scale)),
        child: VerifyPhoneScreen(session: _session()),
      )));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'فاض عند $scale');
      await _close(tester);
    }
  });
}
