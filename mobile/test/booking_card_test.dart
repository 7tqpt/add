// بطاقةُ الحجز في «حجوزاتي» — بعد أن صارت على هيئة بطاقة الخطّة.
//
// ── ما يُقاس ───────────────────────────────────────────────────────────────
//
//   ١. **أنّ شريطَ الدفع وحلقتَه محسوبان من المبلغين** — لا مكتوبَين.
//      وشريطٌ يقول غيرَ ما يقوله الرقمُ إلى جانبه يُقرأ رقمين.
//   ٢. **وأنّ الغلافَ المطلوبَ غلافُ الخدمة المحجوزة** — لا غلافُ غيرها.
//      والحجزان في بيانات العرض لخدمتين لكلٍّ غلافُها، فيُقاس أيُّهما وقع.
//   ٣. **وأنّ العدَّ التنازليَّ من `countdownLabel`** بصيغة العدد العربيّة،
//      ورقمُه مكبَّرٌ ذو خطٍّ يرسمه.
//   ٤. **وأنّ «سُدّد كاملاً» لا تُقال لمن بقي عليه شيء** — ولا عكسُها.
//   ٥. **وأنّ البطاقةَ تبقى تُفتح** — وسهمُها باقٍ كما اختاره صاحبُ المنصّة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/ui/booking_stages.dart';
import 'package:aras/src/ui/kit.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// المسارات التي طُلب لها رابط — **وهذا ما يُقاس لا ما رُسم على الزجاج**.
final List<String> seenPaths = [];

/// **ويُردّ رابطٌ لا `null`.**
///
/// `Api.mediaUrl` تردّ `null` حين لا تُضبط أسرارُ القاعدة، فلا تُبنى `Image`
/// أصلاً. فاختبارٌ يقبل ذلك يقيس شاشةً غيرَ التي على الجهاز — **وقد اختفت
/// بطاقاتُ الحجز كلُّها على جهاز صاحب المنصّة والحزمةُ خضراء**: الصورةُ
/// المرسومةُ بارتفاعٍ لا نهائيٍّ سُئلت عن ارتفاعها الطبيعيّ فأجابت بلا
/// نهاية، فانهار التخطيط. فصار كلُّ اختبارٍ هنا يمرّر رابطاً كما يقع.
void stubMedia() {
  seenPaths.clear();
  Api.mediaUrlOverride = (path) {
    seenPaths.add(path);
    return 'https://example.invalid/$path';
  };
}

/// بطاقةُ حجزٍ بمرجعه.
Finder cardOf(Booking b) => find.ancestor(
      of: find.text(b.reference),
      matching: find.byType(BookingCard),
    );

final List<Booking> _bookings = List.of(demoBookings);

void main() {
  setUp(() {
    demoBookings = List.of(_bookings);
    stubMedia();
  });
  tearDown(() => Api.mediaUrlOverride = null);

  testWidgets('شريطُ الدفع وحلقتُه محسوبان من المبلغين', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    // `b1`: ‎٢٥٥٬٠٠٠‎ من ‎٨٥٠٬٠٠٠‎ = ‎٣٠٪‎.
    final b = demoBookings.firstWhere((x) => x.id == 'b1');
    final card = cardOf(b);
    expect(card, findsOneWidget, reason: 'لم تُوجد بطاقةُ الحجز');

    final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(of: card, matching: find.byType(LinearProgressIndicator)));
    expect(bar.value, closeTo(0.30, 0.001));

    final ring = tester.widget<PercentRing>(
        find.descendant(of: card, matching: find.byType(PercentRing)));
    expect(ring.value, closeTo(0.30, 0.001),
        reason: 'الحلقةُ لا تتبع ما دُفع');

    expect(find.descendant(of: card, matching: find.text('30٪')), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('255,000 ر.ي من 850,000 ر.ي')),
      findsOneWidget,
    );

    // **وحجزٌ آخرُ بنسبةٍ أخرى** — ولولاه لصحّ رقمٌ مكتوبٌ في الشيفرة
    // ومرّ: نسبةُ هذا الحجز ثلاثون، فمن كتبها ثلاثين أصاب مرّةً وأخطأ في
    // كلّ بطاقةٍ سواها.
    final unpaid = demoBookings.firstWhere((x) => x.id == 'b2');
    expect(find.descendant(of: cardOf(unpaid), matching: find.text('0٪')),
        findsOneWidget,
        reason: 'نسبةُ حجزٍ لم يُدفع منه شيءٌ ليست صفراً');
  });

  testWidgets('والغلافُ غلافُ الخدمة المحجوزة لا غلافُ غيرها', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    // **ولكلتا الخدمتين غلافٌ**، فطلبُ الآخر خطأٌ لا نقص.
    expect(seenPaths, contains('p1/s1/hall.jpg'));
    expect(seenPaths, contains('p2/s2/mandi.jpg'));
  });

  testWidgets('والعدُّ التنازليُّ بصيغته العربيّة ورقمُه مكبَّر',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    final b = demoBookings.firstWhere((x) => x.id == 'b1');
    final big = tester.widget<BigNumberIn>(
        find.descendant(of: cardOf(b), matching: find.byType(BigNumberIn)));

    // عرسُ العرض بعد ٢٨ يوماً — والصيغةُ من `countdownLabel` لا من تركيبٍ
    // يدويّ. ومن ركّبها بنفسه أخرج «بقي 2 يوماً» حين يبقى يومان.
    expect(big.text, 'بقي 28 يوماً');

    // **والرقمُ مكبَّرٌ وله خطٌّ يرسمه.** قِطعةٌ تُعلن `fontFamilyFallback`
    // بلا `fontFamily` تُلغي عائلةَ الخطّ الموروثة، فتُرسم الأرقامُ
    // مربّعاتٍ مصمتة — وقد وقع في بطاقة الخطّة.
    final painted = tester.widget<Text>(find.descendant(
      of: find.byType(BigNumberIn),
      matching: find.byType(Text),
    ).first);
    final parts = (painted.textSpan! as TextSpan).children!.cast<TextSpan>();
    final digits = parts.firstWhere((p) => RegExp(r'^\d+$').hasMatch(p.text ?? ''));
    expect(digits.style?.fontSize, greaterThanOrEqualTo(20));
    expect(digits.style?.fontFamilyFallback, isNull,
        reason: 'أسلوبُ الرقم يُعلن احتياطيّاً بلا عائلة — تُرسم أرقامُه مربّعات');

    // **وحجزٌ مضى موعدُه** — ولولاه لصحّ التركيبُ اليدويّ في الحالة الوحيدة
    // التي تُقاس: `'بقي $days يوماً'` تُخرج «بقي 28 يوماً» صواباً، وتُخرج
    // لهذا «بقي ‎-40‎ يوماً».
    final past = demoBookings.firstWhere((x) => x.eventDate.compareTo(
        DateTime.now().toIso8601String().substring(0, 10)) < 0);
    // والقائمةُ كسولةٌ فلا تُبنى إلّا ما يُرى.
    await tester.scrollUntilVisible(
      find.text(past.reference, skipOffstage: false),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final old = tester.widget<BigNumberIn>(
        find.descendant(of: cardOf(past), matching: find.byType(BigNumberIn)));
    expect(old.text, 'مضى 40 يوماً',
        reason: 'حجزٌ مضى موعدُه يقول «بقي» — والجملةُ رُكّبت في الشاشة');
  });

  testWidgets('و«سُدّد كاملاً» لمن سدّد وحدَه', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final b = demoBookings.firstWhere((x) => x.id == 'b1');
    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    // لم يُسدَّد: يُقال كم بقي.
    expect(find.descendant(of: cardOf(b), matching: find.text('سُدّد كاملاً')),
        findsNothing);
    expect(find.descendant(of: cardOf(b), matching: find.text('بقي 595,000 ر.ي')),
        findsOneWidget);
  });

  testWidgets('وسُدّد كاملاً حين يُسدَّد', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final paid = demoBookings.firstWhere((x) => x.id == 'b1');
    demoBookings = [
      for (final x in demoBookings)
        if (x.id == 'b1')
          Booking(
            id: x.id,
            reference: x.reference,
            userName: x.userName,
            providerName: x.providerName,
            serviceTitle: x.serviceTitle,
            planId: x.planId,
            eventDate: x.eventDate,
            eventTime: x.eventTime,
            address: x.address,
            guestsCount: x.guestsCount,
            status: x.status,
            totalPrice: x.totalPrice,
            depositAmount: x.depositAmount,
            paidAmount: x.totalPrice,
            createdAt: x.createdAt,
          )
        else
          x,
    ];

    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    final card = cardOf(paid);
    expect(find.descendant(of: card, matching: find.text('سُدّد كاملاً')),
        findsOneWidget);
    final ring = tester.widget<PercentRing>(
        find.descendant(of: card, matching: find.byType(PercentRing)));
    expect(ring.value, closeTo(1.0, 0.001));
  });

  testWidgets('وتبقى تُفتح، وسهمُها ومراحلُها فيها', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    final b = demoBookings.firstWhere((x) => x.id == 'b1');
    final card = cardOf(b);
    expect(find.descendant(of: card, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
        reason: 'ذهب السهمُ الذي يقول إنّها تُفتح');
    expect(find.descendant(of: card, matching: find.byType(BookingStages)),
        findsOneWidget,
        reason: 'ذهبت مراحلُ الحجز من البطاقة');
  });

  testWidgets('وتبقى البطاقةُ مرسومةً بخطّ الجهاز الكبير وللصورة رابط',
      (tester) async {
    // **وهذه هي التي سقطت على الجهاز**: ارتفاعٌ مأخوذٌ من النصّ يسأل
    // الصورةَ عن ارتفاعها الطبيعيّ، فتُجيب بلا نهايةٍ وتختفي البطاقة.
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: MyBookingsScreen(session: _session())),
        ),
      ),
    ));
    await _settle(tester);

    expect(find.byType(BookingCard), findsWidgets,
        reason: 'اختفت بطاقاتُ الحجز');
    expect(tester.takeException(), isNull, reason: 'انهار تخطيطُ البطاقة');
  });

  group('ملخّصُ الصدر', () {
    testWidgets('عددٌ واحدٌ في الصدارة، وعددان فوق كلمتيهما، ولا سهمَ يكذب',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
      await _settle(tester);

      final card = find.byType(BookingsSummaryCard);
      expect(card, findsOneWidget);

      final summary = BookingsSummary.of(demoBookings);
      expect(summary.count, greaterThan(0), reason: 'لا حجزَ قادمٌ في العرض');

      // العددُ في قرصٍ لا في جملة.
      expect(find.descendant(of: card, matching: find.text('${summary.count}')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('أقرب حجز')),
          findsOneWidget);

      // وقرصان ملوّنان لحالتي الحجز.
      expect(
        find.descendant(of: card, matching: find.text('${summary.confirmed} مؤكّد')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: card,
            matching: find.text('${summary.pending} بانتظار الموافقة')),
        findsOneWidget,
      );

      // **ولا سهمَ يُضغط فلا يقع شيء**: البطاقةُ في الشاشة التي تشير إليها.
      expect(
        find.descendant(
            of: card, matching: find.byIcon(Icons.arrow_forward_ios_rounded)),
        findsNothing,
        reason: 'سهمٌ في الملخّص لا يفتح شيئاً',
      );
    });

    testWidgets('ومن لا قادمَ له يُقال له أين ذهب ما مضى', (tester) async {
      // حجوزٌ كلُّها مضت.
      demoBookings = [
        for (final b in demoBookings)
          Booking(
            id: b.id,
            reference: b.reference,
            userName: b.userName,
            providerName: b.providerName,
            serviceTitle: b.serviceTitle,
            planId: b.planId,
            eventDate: DateTime.now()
                .subtract(const Duration(days: 30))
                .toIso8601String()
                .substring(0, 10),
            eventTime: b.eventTime,
            address: b.address,
            guestsCount: b.guestsCount,
            status: b.status,
            totalPrice: b.totalPrice,
            depositAmount: b.depositAmount,
            paidAmount: b.paidAmount,
            createdAt: b.createdAt,
          ),
      ];

      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
      await _settle(tester);

      final card = find.byType(BookingsSummaryCard);
      // العددُ صفرٌ في القرص — ولا «أقرب حجز».
      expect(find.descendant(of: card, matching: find.text('0')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('أقرب حجز')),
          findsNothing);
      // **ولا يُترك فوق قائمةٍ مملوءةٍ بلا تفسير.**
      expect(
        find.descendant(
            of: card, matching: find.text('حجوزاتك السابقة محفوظة أدناه')),
        findsOneWidget,
      );
    });
  });
}
