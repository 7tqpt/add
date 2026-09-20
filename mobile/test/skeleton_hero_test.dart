// هياكلُ التحميل، وغلافٌ يطير إلى صفحة خدمته.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// الدرجةُ الثالثة (ج) بعد أن شكا أنّ التطبيق «متحجّز»: هياكلُ تحميلٍ بدل
// الدوّارة في منتصف البياض، وانتقالُ الصورة من البطاقة إلى شاشتها.
//
// ── وتصحيحٌ لعددٍ قلتُه ───────────────────────────────────────────────────
//
// قلتُ «اثنتا عشرةَ دوّارةً ولا هيكلَ واحد». والعددُ صحيحٌ ومضلِّل: تلك
// **دوّاراتُ أزرار** — زرٌّ يُرسل، خريطةٌ تُفتح — ولا يصلح الهيكلُ مكانها.
// والذي يصلح له الهيكلُ هو `LoadingBlock` في الشاشات التي تنتظر **صفوفاً**،
// وهي خمسٌ وثلاثون. فهُيكل منها ما ينتظر بطاقات.
//
// ── ولا تُسأل الشاشةُ عمّا فيها ──────────────────────────────────────────
//
// وجودُ `SkeletonList` في الشجرة لا يكفي: قد تُعرض مع القائمة لا قبلَها.
// **فيُقاس الترتيب**: هيكلٌ قبل الوصول، ولا هيكلَ بعده.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/favourites.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/screens/provider_public.dart';
import 'package:aras/src/ui/kit.dart';
import 'package:aras/src/ui/service_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

Session _customer() => Session()
  ..userId = 'u1'
  ..email = 'cust@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initFormatting);

  late Set<String> saved;
  setUp(() {
    saved = {...demoFavourites};
    demoFavourites = {for (final s in demoServices.take(2)) s.id};
  });
  tearDown(() => demoFavourites = saved);

  group('الهيكلُ قبل الوصول', () {
    /// يُبنى ويُضخّ إطاراً واحداً — **ولا يُنتظر**: الانتظارُ هو ما يُقاس.
    Future<void> first(WidgetTester tester, Widget screen) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(screen));
      await tester.pump();
    }

    testWidgets('**حجوزاتي: هيكلٌ لا دوّارة**', (tester) async {
      await first(tester, MyBookingsScreen(session: _customer()));
      expect(find.byType(SkeletonList), findsOneWidget,
          reason: 'لا هيكلَ أثناء الانتظار');
      expect(find.byType(LoadingBlock), findsNothing,
          reason: 'الدوّارةُ باقيةٌ مكان الهيكل');

      // **ثمّ يذهب.** هيكلٌ يبقى مع القائمة يجعل الشاشةَ تبدو كأنّها لم
      // تُحمَّل بعدُ وهي محمَّلة.
      await _settle(tester);
      expect(find.byType(SkeletonList), findsNothing,
          reason: 'الهيكلُ باقٍ بعد وصول الصفوف');
    });

    testWidgets('**والمفضّلةُ كذلك — بمربّعِ صورة**', (tester) async {
      await first(tester, const FavouritesScreen());
      final s = tester.widgetList<SkeletonList>(find.byType(SkeletonList));
      expect(s, isNotEmpty, reason: 'لا هيكلَ في المفضّلة');
      expect(s.first.thumb, isTrue,
          reason: 'بطاقاتُها لها صورةٌ والهيكلُ بلا مربّع');
      // **وتُستنفد المؤقّتاتُ قبل النهاية**: `LoadingBlock` وأخواتُها تضبط
      // مهلاً، واختبارٌ ينتهي قبلها يسقط بـ«مؤقّتاتٌ معلّقة».
      await _settle(tester);
    });

    testWidgets('**ولا يُضغط الهيكل**', (tester) async {
      // هو صورةُ ما سيأتي لا ما أتى، وضغطةٌ عليه تفتح لا شيء.
      await first(tester, MyBookingsScreen(session: _customer()));
      // **وهو ابنٌ لا جَدّ.** سُئل أوّلَ مرّةٍ عن جَدٍّ `IgnorePointer`،
      // فطابق واحداً من الإطار فوق الشاشة كلِّها ومرّ الضابطُ السالبُ ولم
      // يسقط — والسؤالُ كان عن ودجةٍ أخرى لا عن هذه.
      final guard = find.descendant(
        of: find.byType(SkeletonList),
        matching: find.byType(IgnorePointer),
      );
      expect(guard, findsWidgets, reason: 'الهيكلُ يستقبل الضغط');
      expect(tester.widget<IgnorePointer>(guard.first).ignoring, isTrue,
          reason: 'الحارسُ موجودٌ ولا يحرس');
      await _settle(tester);
    });
  });

  group('الغلافُ يطير إلى صفحته', () {
    /// وسومُ `Hero` في الشاشة.
    List<Object> tags(WidgetTester tester) => tester
        .widgetList<Hero>(find.byType(Hero))
        .map((h) => h.tag)
        .toList();

    testWidgets('**من المفضّلة**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const FavouritesScreen()));
      await _settle(tester);

      final covers = tags(tester)
          .where((t) => '$t'.startsWith('service-cover-'))
          .toList();
      expect(covers, isNotEmpty, reason: 'لا غلافَ يطير من المفضّلة');
      // **ولا وسمَ يتكرّر.** وسمان متطابقان في شاشةٍ واحدة يرميان استثناءً
      // وقت الانتقال — فتُغلق الشاشةُ على صاحبها بشاشةٍ حمراء.
      expect(covers.toSet().length, covers.length,
          reason: 'وسمٌ مكرَّر: $covers');
    });

    testWidgets('**ومن ملفّ المزوّد**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
      await _settle(tester);
      await tester.tap(find.text('الخدمات'));
      await _settle(tester);

      final covers = tags(tester)
          .where((t) => '$t'.startsWith('service-cover-'))
          .toList();
      expect(covers, isNotEmpty, reason: 'لا غلافَ يطير من ملفّ المزوّد');
      expect(covers.toSet().length, covers.length,
          reason: 'وسمٌ مكرَّر: $covers');
    });

    testWidgets('**والوسمُ هو وسمُ الخدمة نفسِها**', (tester) async {
      // وسمٌ لا يطابق وسمَ الشاشة الأخرى لا يطير — يظهر الانتقالُ عاديّاً
      // ولا يقول أحدٌ شيئاً.
      _phone(tester);
      await tester.pumpWidget(_wrap(const FavouritesScreen()));
      await _settle(tester);

      final first = demoServices.firstWhere((s) => demoFavourites.contains(s.id));
      expect(tags(tester), contains(serviceHeroTag(first.id)));
    });
  });
}
