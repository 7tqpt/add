// مراحلُ الحجز — ما تقوله السكّةُ في كلّ حال، وأين يقع زرُّ الدفع.
//
// **وأكثرُ ما هنا مقيسٌ بلا شاشة:** `bookingStages` و`bookingPayLabel` دالّتان
// محضتان، وقياسُهما مباشرةً أدقُّ من البحث عن نصوصٍ في شجرةِ عناصر — وأسرع.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/booking_detail.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/ui/booking_stages.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'demo-user'
  ..loading = false;

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

void _phone(WidgetTester tester, {double height = 9000}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Booking _b({
  required BookingStatus status,
  num total = 100000,
  num deposit = 30000,
  num paid = 0,
}) => Booking(
  id: 'x',
  reference: 'BK-X',
  userName: 'أحمد',
  providerName: 'قاعة',
  serviceTitle: 'باقة',
  eventDate: '2026-12-01',
  eventTime: null,
  address: 'صنعاء',
  guestsCount: 100,
  status: status,
  totalPrice: total,
  depositAmount: deposit,
  paidAmount: paid,
);

List<StageMark> _marks(Booking b) => bookingStages(b).map((s) => s.mark).toList();

/// صفحةُ الحجز — وهي موضعُ السكّة منذ أن شيلت من البطاقة.
Widget _detail(Booking b) => BookingDetailScreen(
      booking: b,
      session: _session(),
      reviewed: false,
    );

void main() {
  group('السكّة', () {
    test('**والمنتظِرُ يرى ثلاثاً: ماضيةً وجاريةً وقادمة**', () {
      // وهذه علّةُ الباب كلِّه: كانت شارةُ حالةٍ واحدةٌ تقول أين هو ولا تقول
      // ما بعدَه، فمن حجز لم يدرِ ماذا ينتظر.
      final s = bookingStages(_b(status: BookingStatus.pendingProvider));
      expect(s, hasLength(3));
      expect(_marks(_b(status: BookingStatus.pendingProvider)),
          [StageMark.done, StageMark.current, StageMark.todo]);
    });

    test('ومن وافق مزوّدُه ولم يدفع تجري عليه الثالثة', () {
      expect(_marks(_b(status: BookingStatus.confirmed, paid: 0)),
          [StageMark.done, StageMark.done, StageMark.current]);
    });

    test('**وعربونٌ نصفيٌّ لا يُقفل المرحلة**', () {
      // `paid >= deposit` لا `paid > 0`: من حوّل بعضَ العربون لم يثبت حجزُه،
      // وقفلُ المرحلة عليه يقول له إنّه فرغ وهو لم يفرغ.
      expect(_marks(_b(status: BookingStatus.confirmed, deposit: 30000, paid: 10000)),
          [StageMark.done, StageMark.done, StageMark.current]);
      expect(_marks(_b(status: BookingStatus.confirmed, deposit: 30000, paid: 30000)),
          [StageMark.done, StageMark.done, StageMark.done]);
    });

    test('والمنفَّذُ ثلاثٌ منقضية', () {
      expect(
        _marks(_b(status: BookingStatus.completed, total: 100000, paid: 100000)),
        [StageMark.done, StageMark.done, StageMark.done],
      );
    });
  });

  group('النهايات', () {
    // **ولا تُخمَّن.** من أُلغي حجزُه لا نعلم من الحالة وحدَها أكان المزوّد
    // قد وافق قبلها أم لا، فرسمُ «موافقة» منقضيةً أو منتظرةً كذبٌ في نصف
    // الحالات. فصفٌّ واحدٌ يقول ما وقع، وتُحذف بقيّةُ المراحل.
    for (final (status, title) in [
      (BookingStatus.rejected, 'اعتذر مقدّم الخدمة'),
      (BookingStatus.cancelled, 'أُلغي الحجز'),
      (BookingStatus.expired, 'انقضت مهلة الردّ'),
    ]) {
      test('و«$title» يقطع السكّة ولا يُخمِّن ما قبلَه', () {
        final s = bookingStages(_b(status: status));
        expect(s, hasLength(2), reason: 'خُمِّنت مرحلةٌ لا تُعرف');
        expect(s.last.mark, StageMark.stopped);
        expect(s.last.title, title);
        // ولا مرحلةَ «قادمة» بعد النهاية: لا معنى لعرض ما لن يقع.
        expect(s.map((e) => e.mark), isNot(contains(StageMark.todo)));
      });
    }
  });

  group('زرُّ الدفع', () {
    test('**ولا يُعرض قبل موافقة المزوّد**', () {
      // كان يُعرض والحجزُ ما زال منتظراً، فمن دفع ثمّ اعتُذر عنه صار له مالٌ
      // يُستردّ. ورتّبَ صاحبُ المنصّة المراحلَ فجعل الدفعَ بعد الموافقة.
      expect(bookingPayLabel(_b(status: BookingStatus.pendingProvider)), isNull);
    });

    test('ولا بعد اكتمال المبلغ', () {
      expect(
        bookingPayLabel(_b(status: BookingStatus.confirmed, total: 100000, paid: 100000)),
        isNull,
      );
    });

    test('**ويقول العربونَ أوّلاً ثمّ الباقي — لا العربونَ مرّتين**', () {
      // زرٌّ يَعِد بدفع عربونٍ دُفع ثمّ يردّه الخادم بـ«لا مبلغ مستحقّاً»
      // أسوأُ من غيابه.
      final first = bookingPayLabel(
          _b(status: BookingStatus.confirmed, total: 100000, deposit: 30000, paid: 0));
      expect(first, contains('العربون'));
      expect(first, contains(formatMoney(30000)));

      final rest = bookingPayLabel(
          _b(status: BookingStatus.confirmed, total: 100000, deposit: 30000, paid: 30000));
      expect(rest, contains('أكمل'));
      expect(rest, contains(formatMoney(70000)));
    });

    test('والمستحقُّ هو الباقي لا كاملُ العربون', () {
      // من حوّل ثلثَ عربونه يُطلب منه الثلثان.
      expect(
        bookingPayLabel(
            _b(status: BookingStatus.confirmed, deposit: 30000, paid: 10000)),
        contains(formatMoney(20000)),
      );
    });
  });

  group('في الشاشة', () {
    // **والسكّةُ انتقلت من البطاقة إلى صفحة الحجز.** كانت في بطاقة
    // «حجوزاتي»، ثمّ أرسل صاحبُ المنصّة تصميماً للبطاقة ليس فيه سكّةٌ ولا
    // شريطُ دفعٍ ولا عدٌّ تنازليّ، وعُرضت عليه ثلاثُ خلايا فاختار «تُشال
    // كلُّها كما في صورتك». فما كان يُقاس في البطاقة يُقاس هنا في الصفحة
    // التي تفتحها — **ولم تُحذف ضمانةٌ منها، بل بُدّل موضعُها**.
    testWidgets('**ولا سكّةَ في البطاقة، والسكّةُ في الصفحة بلا زرّ**',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(
          _wrap(Scaffold(body: MyBookingsScreen(session: _session()))));
      await _settle(tester);

      expect(find.byType(BookingCard), findsWidgets, reason: 'لا بطاقاتِ حجز');
      expect(find.byType(BookingStages), findsNothing,
          reason: 'سكّةٌ باقيةٌ في البطاقة — وقد اختار شيلَها');

      // وفي الصفحة: سكّةٌ **تقول ولا تفعل** — وزرُّ الدفع في شريطها الثابت،
      // وموضعُه مقيسٌ في `booking_detail_test.dart`.
      await tester.pumpWidget(_wrap(_detail(demoBookings.first)));
      await _settle(tester);

      final stages = find.byType(BookingStages);
      expect(stages, findsOneWidget, reason: 'لا سكّةَ في صفحة الحجز');
      expect(
        find.descendant(of: stages, matching: find.byType(FilledButton)),
        findsNothing,
        reason: 'زرٌّ باقٍ في السكّة',
      );
    });

    testWidgets('ولا زرَّ دفعٍ على حجزٍ لم يوافق عليه مزوّدُه', (tester) async {
      _phone(tester);
      final pending =
          demoBookings.where((b) => b.status == BookingStatus.pendingProvider);
      expect(pending, isNotEmpty, reason: 'لا حجزَ منتظرٌ في بيانات العرض');

      await tester.pumpWidget(_wrap(_detail(pending.first)));
      await _settle(tester);

      final stages = find.byType(BookingStages);
      expect(stages, findsOneWidget, reason: 'لا سكّةَ في صفحة المنتظِر');
      expect(
        find.descendant(of: stages, matching: find.byType(FilledButton)),
        findsNothing,
        reason: 'زرُّ دفعٍ قبل الموافقة',
      );
    });

    testWidgets('**والمعتذَرُ عنه أحمرُ مقطوع لا ماضٍ**', (tester) async {
      _phone(tester);
      final rejected =
          demoBookings.where((b) => b.status == BookingStatus.rejected);
      expect(rejected, isNotEmpty, reason: 'لا حجزَ معتذَرٌ عنه في العرض');

      await tester.pumpWidget(_wrap(_detail(rejected.first)));
      await _settle(tester);

      expect(find.text('اعتذر مقدّم الخدمة'), findsWidgets);
      final title = tester.widget<Text>(find.text('اعتذر مقدّم الخدمة').first);
      expect(title.style!.color, AppColors.critical);
      // وعلامةُ الصليب تفرّق لمن لا يميّز الألوان.
      expect(find.byIcon(Icons.close_rounded), findsWidgets);
    });

    testWidgets('**وقرصُ المقطوع أحمرُ لا أخضر**', (tester) async {
      // **وهذه كذلك جاءت من ضابطٍ لم يسقط.** كان المقيسُ لونَ **العنوان**
      // وحدَه، فصُبغ القرصُ أخضرَ وبقيت الحزمةُ خضراء — وصحٌّ أخضرُ إلى
      // جانب عنوانٍ أحمرَ يقول شيئين متناقضين في صفٍّ واحد.
      _phone(tester, height: 1200);
      await tester.pumpWidget(_wrap(Scaffold(
        body: BookingStages(
          stages: bookingStages(_b(status: BookingStatus.rejected)),
        ),
      )));
      await _settle(tester);

      final discs = tester
          .widgetList<DecoratedBox>(find.descendant(
            of: find.byType(BookingStages),
            matching: find.byType(DecoratedBox),
          ))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .toList();

      expect(discs, hasLength(2), reason: 'قرصان لمرحلتين');
      expect(discs[0].color, AppColors.good);
      expect(discs[1].color, AppColors.critical, reason: 'قرصُ المقطوع ليس أحمر');
      expect(discs[1].border!.top.color, AppColors.critical);
    });

    testWidgets('**والخيطُ يُلوَّن إلى ما مضى لا إلى آخره**', (tester) async {
      // **وهذه ضمانةٌ جاءت من ضابطٍ لم يسقط.** لُوّن الخيطُ كلُّه أخضرَ
      // فبقيت الحزمةُ خضراء — أي أنّ لونَ السكّة لم يكن مقيساً أصلاً.
      // وخيطٌ أخضرُ إلى آخره يقول إنّ الثلاثةَ مضت وهي لم تمضِ.
      _phone(tester, height: 1200);
      await tester.pumpWidget(_wrap(Scaffold(
        body: BookingStages(
          stages: bookingStages(_b(status: BookingStatus.pendingProvider)),
        ),
      )));
      await _settle(tester);

      // خيوطُ السكّة `ColoredBox` — والأقراصُ `DecoratedBox` فلا تختلط بها.
      final threads = tester
          .widgetList<ColoredBox>(find.descendant(
            of: find.byType(BookingStages),
            matching: find.byType(ColoredBox),
          ))
          .map((c) => c.color)
          .toList();

      expect(threads, hasLength(2), reason: 'خيطان بين ثلاث مراحل');
      expect(threads[0], AppColors.good, reason: 'ما مضى غيرُ ملوَّن');
      expect(threads[1], AppColors.hairline, reason: 'ما لم يمضِ ملوَّن');
    });

    testWidgets('ولا تفيض السكّةُ بخطّ الجهاز الكبير', (tester) async {
      // ارتفاعُها يتبع نصّها، ونصّها يكبر بمقياس خطّ الجهاز.
      for (final scale in [1.3, 2.0]) {
        _phone(tester, height: 9000);
        await tester.pumpWidget(_wrap(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: _detail(demoBookings.first),
        )));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: 'فاضت عند $scale');
        await tester.pumpWidget(const SizedBox.shrink());
        await _settle(tester);
      }
    });
  });
}
