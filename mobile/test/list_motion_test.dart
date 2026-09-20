// القوائمُ تتتابع، والشاشاتُ تُسحب للتحديث.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أحسّ تطبيقَ متحجّز… تطبيقٌ غير تفاعليّ»، ثمّ اختار (ب): تتابعُ ظهور
// القوائم في الشاشات التي تُلقيها دفعةً واحدة، و«سحبٌ للتحديث» حيث ينقص.
//
// ── ولا يُقاس ذلك بالعين ──────────────────────────────────────────────────
//
// التتابعُ حركةٌ تمضي في ربع ثانية، ومن نظر إلى الشاشة بعدها لم يرَ فرقاً.
// **فتُقاس الأداةُ في موضعها**: `FadeSlideIn` في الشجرة وفهرسُها متبدّل —
// فهرسٌ ثابتٌ في كلّ صفٍّ يجعل التتابعَ ظهوراً واحداً بلا تدرّج، **وهو
// عطبٌ لا يُرى إلّا بالمقارنة**.
//
// ── والشاشاتُ الستُّ تُعدّ ولا تُوصف ─────────────────────────────────────
//
// كُتب أنّ ستّاً منها تُلقي قوائمَها دفعةً واحدة. فتُفتح كلُّ واحدةٍ ويُسأل
// عنها بعينها — لا «التطبيقُ فيه تتابع» وهي جملةٌ تصدق بشاشةٍ واحدة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/explore.dart';
import 'package:aras/src/screens/favourites.dart';
import 'package:aras/src/screens/home.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/screens/notifications.dart';
import 'package:aras/src/screens/plan.dart';
import 'package:aras/src/screens/provider_public.dart';
import 'package:aras/src/screens/services.dart';
import 'package:aras/src/ui/motion.dart';

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

Session _provider() => Session()
  ..userId = 'u2'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a2'
  ..providerId = 'demo-provider'
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

/// فهارسُ ما في الشجرة من `FadeSlideIn`.
List<int> _indexes(WidgetTester tester) => tester
    .widgetList<FadeSlideIn>(find.byType(FadeSlideIn))
    .map((w) => w.index)
    .toList();

/// **وبيانات العرض تُزرع هنا وتُردّ بعده.** شاشتان منها تفتحان على فراغٍ
/// في وضع العرض — لا مفضّلةَ محفوظةً ولا خدمةَ لمزوّد — و«لا شيءَ» لا تتابعَ
/// فيه ولا سحب. وزرعُها في الملفّ نفسِه يجعل اختباراً يُفسد أخاه.
void main() {
  setUpAll(initFormatting);

  late Set<String> savedFavourites;
  late List<MyService> savedServices;

  setUp(() {
    savedFavourites = {...demoFavourites};
    savedServices = [...demoMyServices];
    demoFavourites = {for (final s in demoServices.take(3)) s.id};
    demoMyServices = [
      for (final (i, s) in demoServices.take(3).indexed)
        MyService(
          id: 's$i',
          title: s.title,
          description: '',
          price: s.price,
          priceTo: null,
          unit: s.unit,
          depositPercent: 30,
          categoryId: s.categoryId,
          isActive: true,
        ),
    ];
  });
  tearDown(() {
    demoFavourites = savedFavourites;
    demoMyServices = savedServices;
  });

  group('الشاشاتُ الستُّ تتتابع', () {
    Future<void> check(WidgetTester tester, Widget screen, String name,
        {required int atLeast}) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(screen));
      await _settle(tester);

      final ix = _indexes(tester);
      // **ويُعدُّ ما لُفَّ لا وجودُه وحدَه.** «فيها تتابع» تصدق بقسمٍ واحدٍ
      // من ثلاثة — **وقد جُرّب**: رُفع اللفُّ عن أوّل أقسام الرئيسية فبقي
      // اثنان، ومرّ الضابطُ السالبُ ولم يسقط.
      expect(ix.length, greaterThanOrEqualTo(atLeast),
          reason: '$name ينقصها ملفوفٌ — جزءٌ منها يقع دفعةً واحدة');

      // **ولا فهرسَ يتكرّر.** المتكرّرُ يظهر مع سابقه في اللحظة نفسِها،
      // فالأداةُ في الشجرة والقائمةُ تقع كتلةً — ولا يُرى ذلك إلّا بالمقارنة.
      expect(ix.toSet().length, ix.length,
          reason: '$name فيها فهرسٌ مكرَّر: $ix');
    }

    testWidgets('الرئيسية', (t) async {
      // ثلاثةُ أقسام: اللافتاتُ والمميَّزون و«خدماتٌ لك».
      await check(t, HomeScreen(session: _customer(), onGoTo: (_) {}), 'الرئيسية',
          atLeast: 3);
    });

    testWidgets('حجوزاتي', (t) async {
      await check(t, MyBookingsScreen(session: _customer()), 'حجوزاتي', atLeast: 2);
    });

    testWidgets('المفضّلة', (t) async {
      await check(t, const FavouritesScreen(), 'المفضّلة', atLeast: 2);
    });

    testWidgets('الإشعارات', (t) async {
      await check(t, NotificationsScreen(onOpen: (_, _) {}), 'الإشعارات', atLeast: 2);
    });

    testWidgets('خطة العرس', (t) async {
      // ثلاثةُ أقسام: التقدّمُ والبطاقاتُ وقائمةُ التجهيز.
      await check(t, PlanScreen(session: _customer()), 'خطة العرس', atLeast: 3);
    });

    testWidgets('ملفُّ المزوّد', (t) async {
      _phone(t);
      await t.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
      await _settle(t);
      await t.tap(find.text('الخدمات'));
      await _settle(t);

      final ix = _indexes(t);
      expect(ix.length, greaterThanOrEqualTo(2),
          reason: 'خدماتُ المزوّد تقع دفعةً واحدة');
      expect(ix.toSet().length, ix.length, reason: 'فيها فهرسٌ مكرَّر: $ix');
    });
  });

  group('السحبُ للتحديث', () {
    // **ولا تُسأل الدوّارةُ عمّا تفعله.** ظهورُها يعني أنّ الإيماءةَ وصلت،
    // لا أنّ شيئاً قُرئ: `onRefresh` فارغةٌ تُظهرها ثمّ تنطفئ والقائمةُ كما
    // هي. **وقد جُرّب**: أُفرغت في الضابط السالب فلم يسقط.
    //
    // فيُبدَّل شيءٌ في المصدر **بعد** أن تُعرض القائمة، ثمّ يُسحب، ثمّ يُسأل
    // أظهر الجديد.
    Future<void> pull(
      WidgetTester tester,
      Widget screen,
      String name, {
      required void Function() change,
      required Finder fresh,
    }) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(screen));
      await _settle(tester);

      expect(find.byType(RefreshIndicator), findsWidgets,
          reason: '$name بلا سحبٍ للتحديث');
      expect(fresh, findsNothing, reason: 'الجديدُ معروضٌ قبل السحب');

      change();
      await tester.fling(
          find.byType(RefreshIndicator).last, const Offset(0, 320), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RefreshProgressIndicator), findsWidgets,
          reason: '$name لا تستجيب للسحب');
      await _settle(tester);

      expect(fresh, findsWidgets,
          reason: '$name سحبُها يدور ولا يقرأ شيئاً');
    }

    testWidgets('استكشف', (t) async {
      // **والمفضّلةُ تُقرأ مع النتائج**، فتبدّلُها يُرى في القائمة: قلبٌ
      // مملوءٌ حيث كان مفرَّغاً. ولا سبيلَ إلى زرع خدمةٍ جديدةٍ في وضع
      // العرض — `demoServices` ثابتةٌ لا تُبدَّل.
      demoFavourites = {};
      await pull(
        t,
        const ExploreScreen(),
        'استكشف',
        change: () => demoFavourites = {for (final x in demoServices) x.id},
        fresh: find.byIcon(Icons.favorite),
      );
    });

    testWidgets('خدماتي', (t) async {
      // **وتُستبدل القائمةُ لا يُزاد عليها**: بطاقةُ الخدمة طويلة، فرابعةٌ
      // في آخر القائمة لا تُبنى أصلاً — فيُقاس غيابُها وهو من ضِيق الشاشة
      // لا من سحبٍ لا يقرأ.
      await pull(
        t,
        ServicesScreen(session: _provider()),
        'خدماتي',
        change: () => demoMyServices = [
          MyService(
            id: 's-new',
            title: 'خدمةٌ أُضيفت من شاشةٍ أخرى',
            description: '',
            price: 1000,
            priceTo: null,
            unit: 'للحجز',
            depositPercent: 30,
            categoryId: demoServices.first.categoryId,
            isActive: true,
          ),
        ],
        fresh: find.text('خدمةٌ أُضيفت من شاشةٍ أخرى'),
      );
    });
  });
}
