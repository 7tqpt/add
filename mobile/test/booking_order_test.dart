// ترتيبُ الحجوزات والطلبات — **الأحدثُ أوّلاً**.
//
// **والعلّةُ خلطُ تاريخين.** كانت الشاشتان تُرتَّبان بـ`event_date` — تاريخِ
// العرس — لا بوقت إنشاء الحجز. فحجزٌ وصل قبل دقيقةٍ لعرسٍ بعد سنةٍ يقع في
// آخر القائمة تحت عشرةٍ قديمة: مقدّمُ الخدمة يفتح «الطلبات» ليردّ على ما
// وصل فلا يجده، والعميلُ يحجز ثمّ يفتح «حجوزاتي» فلا يرى حجزَه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/ui/kit.dart';

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

void main() {
  group('الطراز', () {
    test('**يقرأ وقتَ الإنشاء من القاعدة**', () {
      final b = Booking.fromMap(const {
        'id': 'x',
        'event_date': '2026-12-01',
        'created_at': '2026-09-07T10:00:00Z',
        'status': 'pending_provider',
      });
      expect(b.createdAt, '2026-09-07T10:00:00Z');
    });

    test('**وقاعدةٌ لا ترسله لا تُسقط الطراز**', () {
      // عمودٌ لم يُطلب في `select` أو قاعدةٌ أقدم — يُقرأ فراغاً لا `null`،
      // فلا يرمي المقارِنُ عند الترتيب.
      final b = Booking.fromMap(const {'id': 'x', 'status': 'confirmed'});
      expect(b.createdAt, isEmpty);
    });
  });

  group('حجوزاتي', () {
    test('**الأحدثُ أوّلاً — ولو كان عرسُه أبعدَ الأعراس**', () async {
      final rows = await Api.myBookings('demo-user');
      expect(rows, hasLength(greaterThan(1)));

      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i - 1].createdAt.compareTo(rows[i].createdAt),
          greaterThanOrEqualTo(0),
          reason: 'حجزٌ أقدمُ فوقَ أحدثَ منه',
        );
      }
    });

    test('**ولكلِّ حجزٍ في العرض وقتُ إنشاء**', () {
      // **وهذا الضمانُ جاء من ضابطٍ لم يسقط.** شُيل وقتُ الإنشاء من حجزٍ
      // واحدٍ فبقيت الحزمةُ خضراء: الفراغُ يُرتَّب في القاع ولا يرمي، فيهبط
      // حجزٌ حديثٌ إلى الأسفل بلا أن يشتكي شيء. وبيانُ العرض هو ما يُقاس به
      // كلُّ ما دونه.
      for (final b in [...demoBookings, ...demoProviderRequests]) {
        expect(b.createdAt, isNotEmpty,
            reason: 'الحجز ${b.reference} بلا وقت إنشاء');
      }
    });

    test('**ولا يُقاس الترتيبُ بتاريخ العرس ولو وافقه صدفةً**', () {
      // **وهذا الضمانُ عن الاختبار نفسِه لا عن الشيفرة.** لو صادف أن ترتيبَ
      // بيانات العرض بالإنشاء هو ترتيبُها بتاريخ العرس، لَمرّ الاختبارُ
      // أعلاه على ترتيبٍ خاطئٍ ولم يُميّز. فيُسأل: أهما مختلفان أصلاً؟
      final byCreated = [...demoBookings]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final byEvent = [...demoBookings]
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
      expect(
        byCreated.map((b) => b.id).toList(),
        isNot(byEvent.map((b) => b.id).toList()),
        reason: 'بياناتُ العرض لا تفرّق الترتيبين — فالاختبارُ لا يقيس شيئاً',
      );
    });

    testWidgets('**وأوّلُ بطاقةٍ في الشاشة هي أحدثُ حجز**', (tester) async {
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          _wrap(Scaffold(body: MyBookingsScreen(session: _session()))));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final newest = ([...demoBookings]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          .first;

      // **وأوّلُ `AppCard` لا أوّلُ نصّ:** الملخّصُ في الصدر `BigHeroCard`
      // فلا يُحسب، والبطاقاتُ بعده بترتيبها.
      final cards = find.byType(AppCard);
      expect(cards, findsWidgets);
      expect(
        find.descendant(of: cards.first, matching: find.text(newest.reference)),
        findsOneWidget,
        reason: 'أوّلُ بطاقةٍ ليست أحدثَ حجز',
      );
    });

    test('**والملخّصُ يبقى بالأقرب موعداً لا بالأحدث**', () {
      // «أقربها ٥ أكتوبر» جوابُ سؤالٍ آخر. ولو تبع ترتيبَ القائمة لَقال
      // «أقربها» عن حجزٍ بعد سنة.
      final s = BookingsSummary.of(demoBookings);
      for (var i = 1; i < s.upcoming.length; i++) {
        expect(
          s.upcoming[i - 1].eventDate.compareTo(s.upcoming[i].eventDate),
          lessThanOrEqualTo(0),
          reason: 'الملخّصُ لم يعد بالأقرب موعداً',
        );
      }
    });
  });

  group('طلباتُ مقدّم الخدمة', () {
    // `demoApproveProvider` هي التي تبني قائمةَ الطلبات — ولا مسؤولَ في وضع
    // العرض يضغط «توثيق».
    setUp(() {
      demoBecomeProvider(
          businessName: 'قاعة التجربة', governorate: 'أمانة العاصمة', bio: '');
      demoApproveProvider();
    });

    test('**الأحدثُ أوّلاً — وهو ما فُتحت الشاشةُ للردّ عليه**', () async {
      final rows = await Api.providerRequests('demo-provider');
      expect(rows, hasLength(greaterThan(1)));
      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i - 1].createdAt.compareTo(rows[i].createdAt),
          greaterThanOrEqualTo(0),
          reason: 'طلبٌ أقدمُ فوقَ أحدثَ منه',
        );
      }
    });

    test('ويفرّق الترتيبان في بيانات العرض', () {
      final byCreated = [...demoProviderRequests]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final byEvent = [...demoProviderRequests]
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
      expect(byCreated.map((b) => b.id).toList(),
          isNot(byEvent.map((b) => b.id).toList()));
    });
  });
}
