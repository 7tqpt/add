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

/// لونُ شارة الحالة كما رُسمت — حبرُها لا أرضيّتُها.
///
/// **وفي أيّ بطاقةٍ كانت**: الشاشةُ فيها طلبان بحالين، فتقييدُ البحث
/// بالأولى يقيس واحدةً ويُسمّيها الحالَين.
Color _badgeColour(WidgetTester tester, String label) =>
    tester.widget<Text>(find.descendant(
      of: find.byType(CardTitleBar),
      matching: find.text(label),
    )).style!.color!;

/// لونُ العنوان كما رُسم.
Color _titleColour(WidgetTester tester, String title) =>
    tester.widget<Text>(find.descendant(
      of: find.byType(CardTitleBar),
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
      // **وطلبان بحالين** — ولولا الثاني لصحّ لونٌ مكتوبٌ في الشيفرة:
      // حالُ الأوّل «بانتظار مقدّم الخدمة» ولونُها الكهرمانيّ، فمن كتبه
      // ثابتاً أصاب فيه وأخطأ في كلّ حالٍ سواه. وضابطٌ كشف ذلك.
      Booking(
        id: 'r0',
        reference: 'BK-0',
        userName: 'نورة الحضرمي',
        providerName: 'قاعة التاج',
        serviceTitle: 'حجز قاعة التاج — منفَّذ',
        eventDate: '2026-01-10',
        eventTime: '18:00',
        address: 'المنصورة — عدن',
        guestsCount: 180,
        status: BookingStatus.completed,
        totalPrice: 300000,
        depositAmount: 90000,
        paidAmount: 300000,
      ),
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
    testWidgets('العنوانُ حبرٌ على أبيض لا على شريطٍ نبيذيّ', (tester) async {
      // **والشكلُ بُدّل بأمر صاحب المنصّة**: أرسل تصميمين وقال إنّ
      // الشاشتين معاً تتبعانه — رأسٌ أبيضُ وشارةٌ ملوّنة.
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      expect(find.byType(CardTitleBar), findsOneWidget);
      expect(_titleColour(tester, 'قاعة التاج'), AppColors.ink,
          reason: 'العنوانُ ليس بحبر الصفحة');
    });

    testWidgets('**والشارةُ استردّت لونَها ولم تفقد كلمتَها**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      // الخدمةُ موقوفةٌ في التهيئة: الكلمةُ لمن يقرأ، واللونُ لمن يلمح.
      expect(
        find.descendant(
          of: find.byType(CardTitleBar),
          matching: find.text('موقوفة'),
        ),
        findsOneWidget,
      );
      expect(_badgeColour(tester, 'موقوفة'), AppColors.muted,
          reason: 'الموقوفةُ بلون المعروضة — واللونُ هو ما يُلمح');

      // وأخرى معروضة: لولاها لصحّ لونٌ واحدٌ للحالين.
      //
      // **وتُفرَّغ الشاشةُ أوّلاً**: `pumpWidget` بودجةٍ من النوع نفسِه
      // يعيد استعمال حالتَها، فلا تُنادى `initState` ولا تُقرأ القائمةُ
      // من جديد — فيُقاس الصفُّ القديمُ ويُظنّ أنّه الجديد.
      demoMyServices = [
        MyService(
          id: 's2',
          title: 'قاعة اللؤلؤة',
          description: '',
          price: 10000,
          priceTo: null,
          unit: 'يوم',
          depositPercent: 30,
          categoryId: 'c1',
          isActive: true,
        ),
      ];
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);
      expect(_badgeColour(tester, 'معروضة'), AppColors.good);
    });
  });

  group('**وفي «الطلبات»** — طلبهما معاً', () {
    testWidgets('العنوانُ حبرٌ على أبيض، وحالُه بلونها', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
      await _settle(tester);

      expect(find.byType(CardTitleBar), findsNWidgets(2));
      expect(_titleColour(tester, 'حجز قاعة التاج'), AppColors.ink);
      expect(
        _badgeColour(tester, bookingStatusLabel(BookingStatus.pendingProvider)),
        bookingStatusColor(BookingStatus.pendingProvider),
        reason: 'لونُ الشارة ليس لونَ الحالة',
      );
      // والمنفَّذُ بلونه هو — ولولاه لصحّ لونٌ واحدٌ مكتوبٌ للحالات كلِّها.
      expect(
        _badgeColour(tester, bookingStatusLabel(BookingStatus.completed)),
        bookingStatusColor(BookingStatus.completed),
        reason: 'حالان بلونٍ واحد',
      );
    });

    testWidgets('**وزرُّ «قبول» طَفليٌّ كما اختار**', (tester) async {
      // عُرض عليه أنّه يفترق عن كلّ زرٍّ مملوءٍ في التطبيق — وكلُّها
      // نبيذيّة — فاختار تصميمَه كما أرسله. وهذا يمنع رجوعَه بلا أن يُسأل.
      _phone(tester);
      await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
      await _settle(tester);

      final accept = find.widgetWithText(FilledButton, 'قبول');
      expect(accept, findsOneWidget, reason: 'لا زرَّ قبولٍ على طلبٍ منتظِر');

      // **ولا يُسأل النمطُ أهو موجود، بل ما اللونُ الذي يُرسم به.**
      final style = tester.widget<FilledButton>(accept).style!;
      final colour = style.backgroundColor!.resolve(<WidgetState>{});
      expect(colour, AppColors.brand, reason: 'لونُ «قبول» ليس الطَّفليّ');
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

  group('وألوانُ الرأس تُقرأ', () {
    test('**حبرُ العنوان على أرضيّة البطاقة فوق العتبة**', () {
      final r = _ratio(AppColors.ink, AppColors.surface);
      expect(r, greaterThanOrEqualTo(4.5),
          reason: 'حبرُ العنوان يعطي ${r.toStringAsFixed(2)}:1');
    });

    testWidgets('**ولونُ الشارة على صبغتها كما رُسمت فوق العتبة**',
        (tester) async {
      // **وهذا هو ما ربحه الشكلُ الجديد**: على الشريط النبيذيّ كان أخضرُ
      // «معروضة» يعطي ‎١٫٧:١‎ فبُيّضت الشاراتُ كلُّها. وعلى الصبغة الفاتحة
      // يُقرأ لونُها — فتُلتقط الحالُ بلمحةٍ قبل أن تُتهجّى.
      //
      // **والصبغةُ تُقرأ من الشجرة لا تُحسب هنا.** كُتب هذا أوّلاً بنسبةٍ
      // مكتوبةٍ في الاختبار، **فكان يقيس حسابَه هو لا ما رُسم** — وضابطٌ
      // أعاد الصبغةَ إلى اثنتَي عشرةَ بالمئة لم يُسقطه.
      _phone(tester);
      await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
      await _settle(tester);

      final label = bookingStatusLabel(BookingStatus.pendingProvider);
      final ink = _badgeColour(tester, label);
      final pill = tester.widget<Container>(find.ancestor(
        of: find.text(label),
        matching: find.byType(Container),
      ).first);
      final tintOnCard = Color.alphaBlend(
        ((pill.decoration! as BoxDecoration).color)!,
        AppColors.surface,
      );

      final r = _ratio(ink, tintOnCard);
      expect(r, greaterThanOrEqualTo(4.5),
          reason: 'لونُ الشارة على صبغتها ${r.toStringAsFixed(2)}:1');
    });

    test('**وأخضرُ الشارة لا يُقرأ على النبيذيّ** — وهو سببُ تركه', () {
      final r = _ratio(AppColors.good, AppColors.accent);
      expect(r, lessThan(4.5),
          reason: 'أخضرُ «معروضة» على النبيذيّ ${r.toStringAsFixed(2)}:1');
    });
  });
}
