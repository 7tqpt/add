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
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/booking_detail.dart';
import 'package:aras/src/screens/chat.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/ui/booking_stages.dart';
import 'package:aras/src/ui/kit.dart';
import 'package:aras/src/ui/media.dart';

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

  testWidgets('حقائقُ البطاقة الأربعُ من الحجز لا مكتوبةٌ فيها',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    final b = demoBookings.firstWhere((x) => x.id == 'b1');
    final card = cardOf(b);
    expect(card, findsOneWidget, reason: 'لم تُوجد بطاقةُ الحجز');

    Finder inCard(String text) =>
        find.descendant(of: card, matching: find.text(text));

    // **والقيمُ من دوالّ الصيغ لا من نصٍّ مكتوب**: من كتب التاريخَ حرفاً
    // أصاب في بطاقةٍ وأخطأ في كلّ بطاقةٍ سواها.
    expect(inCard(tr('التاريخ')), findsOneWidget);
    expect(inCard(formatDate(b.eventDate)), findsOneWidget);
    expect(inCard(tr('الوقت')), findsOneWidget);
    expect(inCard(formatTime(b.eventTime)), findsOneWidget);
    expect(inCard(tr('رقم الحجز')), findsOneWidget);
    expect(inCard(b.reference), findsOneWidget);
    expect(inCard(tr('السعر')), findsOneWidget);
    expect(inCard(formatMoney(b.totalPrice)), findsOneWidget);

    // **وحجزٌ ثانٍ بثمنٍ آخرَ وموعدٍ آخر** — ولولاه لصحّ رقمٌ مكتوبٌ ومرّ.
    final other = demoBookings.firstWhere((x) => x.id == 'b2');
    expect(other.totalPrice, isNot(b.totalPrice));
    expect(
      find.descendant(
          of: cardOf(other), matching: find.text(formatMoney(other.totalPrice))),
      findsOneWidget,
      reason: 'ثمنُ بطاقةٍ أخرى ليس ثمنَها',
    );
    expect(
      find.descendant(
          of: cardOf(other), matching: find.text(formatTime(other.eventTime))),
      findsOneWidget,
    );
  });

  testWidgets('ورقمُ الحجز كاملاً في صفحة الحجز', (tester) async {
    // **والعمودُ ربعُ عرض الجوال فلا يسعه.** عُرض ذلك على صاحب المنصّة —
    // «ورقمُ الحجز يُقصّ: BK-2026-0…» — فاختار الصفَّ الواحدَ على علم.
    // وجُرّب تصغيرُه ليُقرأ كاملاً (`BoxFit.scaleDown`) فخرج بخُمس حجمه.
    //
    // **فالمقيسُ أنّ الرقمَ لم يضع**: هو الذي يُقال للمزوّد في الهاتف،
    // ويُقرأ كاملاً في الصفحة التي تفتحها البطاقة.
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final b = demoBookings.firstWhere((x) => x.id == 'b1');
    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    await tester.tap(find.descendant(
        of: cardOf(b), matching: find.byKey(ValueKey('open-${b.id}'))));
    await _settle(tester);

    expect(find.byType(BookingDetailScreen), findsOneWidget);
    final shown = tester.widget<Text>(find.descendant(
      of: find.byType(BookingDetailScreen),
      matching: find.text(b.reference),
    ).first);
    expect(shown.data, b.reference, reason: 'الرقمُ ناقصٌ في الصفحة كذلك');
  });

  testWidgets('وشارةُ الحالة بلون الحالة، ولا علامةَ صحٍّ للمرفوض',
      (tester) async {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    final ok = demoBookings.firstWhere((x) => x.status == BookingStatus.confirmed);
    final okCard = cardOf(ok);
    expect(find.descendant(of: okCard, matching: find.text(tr('مؤكد'))),
        findsOneWidget);
    final okIcon = tester.widget<Icon>(find.descendant(
        of: okCard, matching: find.byIcon(Icons.check_circle_rounded)));
    expect(okIcon.color, AppColors.good);

    // **والمرفوضُ لا يُرسم له صحٌّ أحمر** — يُقرأ لمحةً على أنّه تمّ.
    final bad = demoBookings.firstWhere((x) => x.status == BookingStatus.rejected);
    await tester.scrollUntilVisible(
      find.text(bad.reference, skipOffstage: false),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final badCard = cardOf(bad);
    expect(find.descendant(of: badCard, matching: find.text(tr('مرفوض'))),
        findsOneWidget);
    expect(
      find.descendant(
          of: badCard, matching: find.byIcon(Icons.check_circle_rounded)),
      findsNothing,
      reason: 'علامةُ صحٍّ على حجزٍ اعتُذر عنه',
    );
    final badIcon = tester.widget<Icon>(
        find.descendant(of: badCard, matching: find.byIcon(Icons.cancel_rounded)));
    expect(badIcon.color, AppColors.critical);
  });

  testWidgets('و«عرض الحجز» يفتح صفحتَه', (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    final b = demoBookings.firstWhere((x) => x.id == 'b1');
    final button = find.descendant(
        of: cardOf(b), matching: find.byKey(ValueKey('open-${b.id}')));

    // **والزرُّ نفسُه يُسأل أحيٌّ هو**، لا الضغطةُ وحدَها: البطاقةُ كلُّها
    // تُفتح بالضغط كذلك، فلو مات الزرُّ لالتقطت الضغطةَ البطاقةُ من تحته
    // وفُتحت الصفحةُ — فتمرّ ضغطةٌ على زرٍّ ميّتٍ وكأنّها منه. وقد كشف ذلك
    // ضابطٌ لم يسقط.
    final ink = tester.widget<InkWell>(
        find.descendant(of: button, matching: find.byType(InkWell)).first);
    expect(ink.onTap, isNotNull, reason: 'زرُّ «عرض الحجز» ميّت');

    await tester.tap(button);
    await _settle(tester);

    expect(find.byType(BookingDetailScreen), findsOneWidget,
        reason: 'الزرُّ لا يفتح صفحةَ الحجز');
  });

  testWidgets('و«تواصل مع المزوّد» يفتح محادثةَ مزوّدِ هذا الحجز',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    // **وحجزٌ مزوّدُه ليس الأوّل** — ولولاه لصحّ فتحُ محادثةِ أوّلِ مزوّدٍ
    // دائماً ومرّ: بطاقةٌ تفتح محادثةَ قاعةٍ أخرى تُرسل سؤالَه إلى غريب.
    final b = demoBookings.firstWhere((x) => x.id == 'b2');
    expect(b.providerId, isNotEmpty);
    expect(b.providerId, isNot(demoBookings.first.providerId));

    await tester.tap(find.descendant(
        of: cardOf(b), matching: find.byKey(ValueKey('chat-${b.id}'))));
    await _settle(tester);

    // **والمقيسُ الخيطُ الذي فُتح لا الاسمُ المكتوبُ في الرأس.** رأسُ
    // الشاشة يأخذ اسمَ المزوّد ومعرّفَه من البطاقة رأساً، فيُريان صوابَين
    // ولو فُتح خيطُ غيره — **وقد مرّ ضابطٌ يفتح محادثةَ `p1` دائماً وهما
    // صحيحان**. فيُقاس ما ردّته `openConversation` لمزوّد هذا الحجز.
    final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
    expect(chat.conversationId, demoOpenConversation(b.providerId),
        reason: 'فُتح خيطُ مزوّدٍ غيرِ مزوّد الحجز');
    expect(
      chat.conversationId,
      isNot(demoOpenConversation(demoBookings.first.providerId)),
      reason: 'خيطُ المزوّدَين واحد — فالقياسُ لا يفرّق',
    );
    expect(chat.providerId, b.providerId);
    expect(chat.otherName, b.providerName);
  });

  testWidgets('ولا زرَّ محادثةٍ لحجزٍ لا معرّفَ لمزوّده', (tester) async {
    // **ولا يُوعَد بما يسقط**: صفٌّ من قاعدةٍ أقدمَ لا يحمل العمود، وفتحُ
    // محادثةٍ بمعرّفٍ فارغٍ خطأٌ من الخادم بعد ضغطةٍ في وجهه.
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final b = demoBookings.first;
    final bare = Booking(
      id: b.id,
      reference: b.reference,
      userName: b.userName,
      providerName: b.providerName,
      serviceTitle: b.serviceTitle,
      eventDate: b.eventDate,
      eventTime: b.eventTime,
      address: b.address,
      guestsCount: b.guestsCount,
      status: b.status,
      totalPrice: b.totalPrice,
      depositAmount: b.depositAmount,
      paidAmount: b.paidAmount,
    );
    expect(bare.providerId, isEmpty, reason: 'الافتراضُ ليس فارغاً');

    await tester.pumpWidget(_wrap(Center(
      child: BookingCard(booking: bare, onMessage: () {}),
    )));
    await _settle(tester);

    expect(find.text(tr('عرض الحجز')), findsOneWidget);
    expect(find.text(tr('تواصل مع المزوّد')), findsNothing,
        reason: 'زرُّ محادثةٍ بلا مزوّدٍ يُفتح به');
  });

  testWidgets('ولا شريطَ دفعٍ ولا عدَّ تنازليٍّ ولا مراحلَ في البطاقة',
      (tester) async {
    // **ثلاثتُها كانت فيها، وشيلت بأمرِه.** عُرضت عليه ثلاثُ خلايا: تصميمُه
    // حرفاً، وتصميمُه بالشريط، وتصميمُه بالشريط والمراحل — فاختار «تُشال
    // كلُّها كما في صورتك». وهذا يمنع عودتَها بلا أن يُسأل.
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _session())));
    await _settle(tester);

    final card = cardOf(demoBookings.firstWhere((x) => x.id == 'b1'));
    expect(
      find.descendant(of: card, matching: find.byType(LinearProgressIndicator)),
      findsNothing,
      reason: 'شريطُ الدفع عاد إلى البطاقة',
    );
    expect(find.descendant(of: card, matching: find.byType(PercentRing)),
        findsNothing, reason: 'حلقةُ النسبة عادت إلى البطاقة');
    expect(find.descendant(of: card, matching: find.byType(BigNumberIn)),
        findsNothing, reason: 'العدُّ التنازليُّ عاد إلى البطاقة');
    expect(find.descendant(of: card, matching: find.byType(BookingStages)),
        findsNothing, reason: 'المراحلُ عادت إلى البطاقة');
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

  // **وثلاثُ ضماناتٍ كانت هنا ذهبت مع ما تقيسه، لا بإهمال:**
  //
  //   ١. شريطُ الدفع وحلقتُه، و«سُدّد كاملاً»/«بقي كذا» — شيلت من البطاقة
  //      بأمر صاحب المنصّة، وهي **مقيسةٌ في موضعها الجديد**:
  //      `booking_detail_test.dart` يقيس المبالغَ في صفحة الحجز.
  //   ٢. والعدُّ التنازليُّ بصيغة العدد العربيّة، وخطُّ رقمه المكبَّر —
  //      مقيسان في `plan_test.dart`، فـ`countdownLabel` و`BigNumberIn`
  //      باقيتان في بطاقة الخطّة.
  //   ٣. وعودتُها إلى البطاقة مقيسةٌ أعلاه في «ولا شريطَ دفعٍ ولا عدَّ
  //      تنازليٍّ ولا مراحل».

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

    // ── خيطُ اللُّحمة ────────────────────────────────────────────────────────
    //
    // **ولا يُسأل الشجرةُ هنا، بل تُقرأ البكسلات.** كان لوحُ التلاشي يبدأ
    // بلونٍ صلبٍ فوق تدرّجٍ قُطريّ، فيقع عند حدّه **خيطٌ رأسيٌّ** رآه صاحبُ
    // المنصّة في اللقطة. وسؤالُ الشجرة «أفيك لوحٌ؟» لا يكشف خيطاً، فتُصوَّر
    // البطاقةُ ويُمسح صفٌّ من بكسلاتها: تدرّجٌ صحيحٌ لا يقفز بين بكسلٍ وجاره.
    //
    // **وحالُ «بلا غلاف» هي المقيسة** لأنّها لا تحتاج شبكةً أصلاً: لا صورةَ
    // فيها تُحمَّل، فالبطاقةُ كلُّها تدرّجٌ واحدٌ يجب ألّا ينكسر.
    testWidgets('ولا خيطَ رأسيّاً في تدرّج البطاقة', (tester) async {
      tester.view.physicalSize = const Size(360, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // بلا غلافٍ لأقرب حجز — فلا `Image` تُبنى ولا شبكةَ تُنتظر.
      final bare = BookingsSummary.of(
        [for (final b in demoBookings) b.withCover(null)],
      );
      expect(bare.next, isNotNull, reason: 'لا حجزَ قادمٌ فلا بطاقةَ تُصوَّر');

      await tester.pumpWidget(_wrap(Center(
        child: RepaintBoundary(
          key: const ValueKey('summary-paint'),
          child: SizedBox(width: 340, child: BookingsSummaryCard(summary: bare)),
        ),
      )));
      await _settle(tester);

      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('summary-paint')));
      late ByteData pixels;
      late int width;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        width = image.width;
        pixels = (await image.toByteData())!;
        image.dispose();
      });

      // صفٌّ قريبٌ من أعلى البطاقة — فوق النصّ كلِّه، فلا حرفَ يقطعه.
      const y = 4;
      int channel(int x, int c) => pixels.getUint8(((y * width) + x) * 4 + c);

      var worst = 0;
      var worstAt = 0;
      // وتُترك الأركانُ المدوّرةُ خارج المسح — تنعيمُها قفزةٌ مشروعة.
      for (var x = 31; x < width - 30; x++) {
        for (var c = 0; c < 3; c++) {
          final jump = (channel(x, c) - channel(x - 1, c)).abs();
          if (jump > worst) {
            worst = jump;
            worstAt = x;
          }
        }
      }

      expect(
        worst,
        lessThan(8),
        reason: 'قفزةُ لونٍ قدرُها $worst عند البكسل $worstAt — خيطٌ رأسيّ',
      );
    });

    // **وحين يكون للغلاف صورة**: تذوب هي بشفافيّتها (`BlendMode.dstIn`) ولا
    // يُوضع فوقها لوحُ لونٍ صلب — وذلك اللوحُ كان منبعَ الخيط.
    testWidgets('والغلافُ يذوب بشفافيّته لا بلوحٍ فوقه', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // في بيانات العرض أقربُ حجزٍ لخدمةٍ بلا صور، فيُعطى غلافاً هنا صراحةً
      // — وإلّا قِيست حالُ «بلا غلاف» مرّتين ولم يُقَس الذوبان.
      final bare = BookingsSummary.of(demoBookings);
      expect(bare.next, isNotNull, reason: 'لا حجزَ قادمٌ في العرض');
      final covered = BookingsSummary.of([
        for (final b in demoBookings)
          b.id == bare.next!.id ? b.withCover('p2/s2/mandi.jpg') : b,
      ]);

      await tester.pumpWidget(
          _wrap(Center(child: BookingsSummaryCard(summary: covered))));
      await _settle(tester);

      final card = find.byType(BookingsSummaryCard);
      final cover = find.descendant(of: card, matching: find.byType(MediaThumb));
      expect(cover, findsOneWidget,
          reason: 'لا غلافَ في الملخّص — فالمقيسُ غيرُ موجود');

      final mask = tester.widget<ShaderMask>(
        find.ancestor(of: cover, matching: find.byType(ShaderMask)).first,
      );
      expect(mask.blendMode, BlendMode.dstIn,
          reason: 'الصورةُ لا تذوب بشفافيّتها');
    });
  });
}
