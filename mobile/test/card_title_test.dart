// عنوانُ البطاقة — شريطٌ نبيذيٌّ وحبرٌ أبيض، في «خدماتي» و«الطلبات».
//
// ── ما يحرسه هذا الملفّ ──────────────────────────────────────────────────────
//
// اختار صاحبُ المنصّة **(ج) شريطٌ داخلَ الحشوة** من ثلاثةِ أشكالٍ عُرضت
// عليه، وطلبها في الشاشتين معاً: «كذا لك في الطلبات نفس شيء».
//
// **١) أنّ الشريطَ نبيذيٌّ فعلاً والحبرَ أبيضُ فعلاً** — يُقاس من النمط
//    المرسوم لا من الشيفرة المكتوبة.
// **٢) وأنّه في الشاشتين معاً** — طلبهما معاً، وشاشةٌ تُنسى تبقى بيضاءَ
//    شهوراً ولا ينبّه شيء.
// **٣) وأنّ الأبيضَ يُقرأ على النبيذيّ** — تُحسب النسبةُ هنا ولا تُنقل من
//    تعليق: أرقامُ التباين في التعليقات تعتّق حين يتبدّل لونٌ واحد.
// **٤) وأنّ الشارةَ باقيةٌ** — «موقوفة» و«بانتظار مقدّم الخدمة» تُقرآن من
//    الكلمة بعد أن فقدتا لونَهما، فلو سقطت الكلمةُ لم يبقَ شيء.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/labels.dart';
import 'package:aras/src/screens/requests.dart';
import 'package:aras/src/screens/services.dart';
import 'package:aras/src/ui/kit.dart';

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

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

// ── نسبةُ التباين ───────────────────────────────────────────────────────────
double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// أرضيّةُ الشريط كما رُسمت — من `BoxDecoration` لا من الشيفرة.
Color _barColour(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(CardTitleBar).first,
      matching: find.byType(Container),
    ).first,
  );
  return ((box.decoration! as BoxDecoration).color)!;
}

/// لونُ العنوان كما رُسم.
Color _titleColour(WidgetTester tester, String title) =>
    tester.widget<Text>(find.descendant(
      of: find.byType(CardTitleBar).first,
      matching: find.text(title),
    )).style!.color!;

void main() {
  setUp(() {
    demoMyServices = [
      const MyService(
        id: 's1',
        title: 'قاعة التاج',
        description: 'قاعة التاج التاريخية',
        price: 10000,
        priceTo: 100000,
        unit: 'يوم',
        depositPercent: 30,
        categoryId: 'c1',
        isActive: false,
      ),
    ];
    demoProviderRequests = [
      Booking(
        id: 'r1',
        reference: 'BK-1',
        userName: 'سالم باحميد',
        providerName: 'قاعة التاج',
        serviceTitle: 'حجز قاعة التاج',
        eventDate: DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
            .substring(0, 10),
        eventTime: '20:00',
        address: 'شارع الستين — صنعاء',
        guestsCount: 350,
        status: BookingStatus.pendingProvider,
        totalPrice: 700000,
        depositAmount: 210000,
        paidAmount: 0,
      ),
    ];
  });

  group('**في «خدماتي»**', () {
    testWidgets('العنوانُ في شريطٍ نبيذيٍّ بحبرٍ أبيض', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      expect(find.byType(CardTitleBar), findsOneWidget);
      expect(_barColour(tester), AppColors.accent,
          reason: 'الشريطُ ليس نبيذيّاً');
      expect(_titleColour(tester, 'قاعة التاج'), AppColors.accentInk,
          reason: 'العنوانُ ليس أبيض');
    });

    testWidgets('**والشارةُ باقيةٌ تُقرأ بكلمتها**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      // الخدمةُ موقوفةٌ في التهيئة — وبلا الكلمة لا يبقى ما يقولها، فاللونُ
      // ذهب في هذا الشكل.
      expect(
        find.descendant(
          of: find.byType(CardTitleBar),
          matching: find.text('موقوفة'),
        ),
        findsOneWidget,
      );
    });
  });

  group('**وفي «الطلبات»** — طلبهما معاً', () {
    testWidgets('العنوانُ في شريطٍ نبيذيٍّ بحبرٍ أبيض', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
      await _settle(tester);

      expect(find.byType(CardTitleBar), findsOneWidget);
      expect(_barColour(tester), AppColors.accent);
      expect(_titleColour(tester, 'حجز قاعة التاج'), AppColors.accentInk);
    });

    testWidgets('وحالُ الحجز في الشريط', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
      await _settle(tester);

      expect(
        find.descendant(
          of: find.byType(CardTitleBar),
          matching: find.text(bookingStatusLabel(BookingStatus.pendingProvider)),
        ),
        findsOneWidget,
      );
    });
  });

  group('والأبيضُ يُقرأ على النبيذيّ', () {
    test('**فوق العتبة**', () {
      final r = _ratio(AppColors.accentInk, AppColors.accent);
      expect(r, greaterThanOrEqualTo(4.5),
          reason: 'حبرُ الشريط يعطي ${r.toStringAsFixed(2)}:1');
    });

    test('**وأخضرُ الشارة لا يُقرأ عليه** — وهو سببُ تبييضها', () {
      // لو عاد أحدٌ يوماً فأدخل `StatusBadge` بلونه في الشريط، هذا الرقمُ
      // هو الذي يقول لماذا لا يصحّ.
      final r = _ratio(AppColors.good, AppColors.accent);
      expect(r, lessThan(4.5),
          reason: 'أخضرُ «معروضة» على النبيذيّ ${r.toStringAsFixed(2)}:1');
    });
  });
}
