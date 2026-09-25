// شاشةُ تفصيل الحجز، والبطاقةُ التي تفتحها.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// شكا أنّ «البطاقات غير قابلة للضغط وتطبيقٌ غير تفاعليّ»، ولم تكن لبطاقة
// «حجوزاتي» وجهةٌ أصلاً: كانت تحمل أفعالَها كلَّها أزراراً في أسفلها. فاختار
// أن تُبنى الشاشة (ب: شريطٌ ثابتٌ أسفلَها) وأن **تُنقل إليها الأفعال** (٢).
//
// ── وأخطرُ ما يُقاس هنا: فعلٌ ضاع في النقل ───────────────────────────────
//
// الأزرارُ نُقلت من ملفٍّ إلى ملف. وزرٌّ يسقط في النقل لا يُرى نقصُه: البطاقةُ
// تبدو أنظفَ، والشاشةُ تبدو كاملة، ولا يكتشف أحدٌ أنّ «الإلغاء» ذهب إلّا من
// أراد أن يُلغي. **فتُعدّ الأفعالُ الأربعةُ في وجوهها**.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/geo.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/booking_detail.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/ui/booking_stages.dart';

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

Session _customer() => Session()
  ..userId = 'u1'
  ..email = 'cust@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

Booking _booking({
  BookingStatus status = BookingStatus.confirmed,
  num paid = 255000,
  GeoPoint? point,
  num discount = 50000,
}) =>
    Booking(
      id: 'b1',
      reference: 'BK-2026-000318',
      userName: 'أحمد الشرعبي',
      providerName: 'قاعة التاج الملكي',
      serviceTitle: 'قاعة التاج — باقة شاملة',
      eventDate: '2026-11-28',
      eventTime: '20:00',
      address: 'حيّ السنينة — صنعاء',
      guestsCount: 400,
      status: status,
      totalPrice: 850000,
      depositAmount: 255000,
      paidAmount: paid,
      couponCode: 'FARHATI10',
      discountAmount: discount,
      point: point,
      createdAt: '2026-09-01T10:00:00Z',
    );

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

/// **والقائمةُ كسولةٌ فلا تُبنى إلّا ما يُرى.** أقسامُ الشاشة أطولُ من
/// شاشة الجوال، فيُمرَّر إلى آخرها قبل أن يُسأل عمّا في أسفلها — وإلّا قيل
/// «لا زرَّ إلغاء» وهو موجودٌ تحت الطيّة.
Future<void> _toEnd(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -1400));
  await _settle(tester);
}

Widget _detail(Booking b, {bool reviewed = false, Dispute? dispute}) => _wrap(
      BookingDetailScreen(
        booking: b,
        session: _customer(),
        reviewed: reviewed,
        dispute: dispute,
      ),
    );

void main() {
  setUpAll(initFormatting);

  group('الشاشة', () {
    testWidgets('**أقسامُها الأربعة**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_detail(_booking()));
      await _settle(tester);

      expect(find.text('تفاصيل الحجز'), findsOneWidget);
      expect(find.text('أين وصل حجزك'), findsOneWidget);
      expect(find.text('المبالغ'), findsOneWidget);
      expect(find.byType(BookingStages), findsOneWidget);

      await _toEnd(tester);
      expect(find.text('تفاصيل المناسبة'), findsOneWidget);
    });

    testWidgets('**وشريطُ الدفع ثابتٌ أسفلَها لا في آخر القائمة**',
        (tester) async {
      // اختار (ب): الفعلُ الأوّل لا ينزل مع الصفحة. فيُقاس أنّه **خارج**
      // القائمة — لا أنّه موجودٌ فحسب.
      _phone(tester);
      await tester.pumpWidget(_detail(_booking()));
      await _settle(tester);

      final pay = find.byKey(const ValueKey('booking-pay'));
      expect(pay, findsOneWidget, reason: 'لا زرَّ دفع');
      expect(
        find.ancestor(of: pay, matching: find.byType(ListView)),
        findsNothing,
        reason: 'زرُّ الدفع داخل القائمة — ينزل معها',
      );
      // والمبلغُ معه: زرٌّ يقول «ادفع» بلا رقمٍ يُضغط على الظنّ.
      expect(find.text('المطلوب الآن'), findsOneWidget);
    });

    testWidgets('**والمستحقُّ محسوبٌ بعد الخصم لا قبله**', (tester) async {
      // خطأٌ هنا يُري صاحبَه مبلغاً أكبرَ ممّا سيدفع.
      _phone(tester);
      await tester.pumpWidget(_detail(_booking()));
      await _settle(tester);

      // ٨٥٠٬٠٠٠ − ٥٠٬٠٠٠ خصماً − ٢٥٥٬٠٠٠ مدفوعاً = ٥٤٥٬٠٠٠
      expect(find.text(formatMoney(545000)), findsWidgets);
    });

    testWidgets('**ولا خصمَ يُذكر إن لم يكن**', (tester) async {
      // سطرٌ بصفرٍ يُقرأ خصماً لم يصل.
      _phone(tester);
      await tester.pumpWidget(_detail(_booking(discount: 0)));
      await _settle(tester);

      expect(find.textContaining('خصمُ الكود'), findsNothing);
    });

    testWidgets('**ولا زرَّ خريطةٍ لمن لا نقطةَ له**', (tester) async {
      // زرٌّ يفتح خريطةً على لا شيء أسوأُ من غيابه.
      _phone(tester);
      await tester.pumpWidget(_detail(_booking()));
      await _toEnd(tester);
      expect(find.byKey(const ValueKey('booking-map')), findsNothing);

      await tester.pumpWidget(_detail(_booking(point: GeoPoint(15.3, 44.2))));
      await _toEnd(tester);
      expect(find.byKey(const ValueKey('booking-map')), findsOneWidget);
    });
  });

  group('الأفعالُ الأربعةُ لم يسقط منها شيءٌ في النقل', () {
    testWidgets('الدفعُ والإلغاءُ والنزاعُ على حجزٍ مؤكَّد', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_detail(_booking()));
      await _toEnd(tester);

      expect(find.byKey(const ValueKey('booking-pay')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-cancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-dispute')), findsOneWidget);
      // ولا تقييمَ قبل التنفيذ.
      expect(find.byKey(const ValueKey('booking-review')), findsNothing);
    });

    testWidgets('والتقييمُ على المنفَّذ — مرّةً واحدة', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_detail(_booking(status: BookingStatus.completed)));
      await _toEnd(tester);
      expect(find.byKey(const ValueKey('booking-review')), findsOneWidget);
      // ولا إلغاءَ بعد التنفيذ: القاعدةُ ترفضه، فإظهارُه وعدٌ كاذب.
      expect(find.byKey(const ValueKey('booking-cancel')), findsNothing);

      // **وقد قُيّم**: القاعدةُ تمنع الثانية بقيدٍ فريد.
      await tester.pumpWidget(
        _detail(_booking(status: BookingStatus.completed), reviewed: true),
      );
      await _toEnd(tester);
      expect(find.byKey(const ValueKey('booking-review')), findsNothing);
    });
  });

  group('البطاقةُ في القائمة', () {
    testWidgets('**صارت ملخّصاً: لا أزرارَ فيها**', (tester) async {
      // (٢) — والأزرارُ في موضعين تجعل أحدَهما يبدو غيرَ الآخر.
      _phone(tester);
      await tester.pumpWidget(_wrap(MyBookingsScreen(session: _customer())));
      await _settle(tester);

      expect(find.byType(BookingCard), findsWidgets, reason: 'لا حجوزات');
      expect(find.text('إلغاء الحجز'), findsNothing,
          reason: 'أزرارُ الأفعال باقيةٌ في البطاقة');
      expect(find.text('عندي مشكلة في هذا الحجز'), findsNothing);
    });

    testWidgets('**وتُعاد قراءةُ القائمة بعد تغييرٍ في الشاشة**',
        (tester) async {
      // **وهذا ما لم يكن مقيساً.** الشاشةُ تعود بـ`true` حين يقع تغيير،
      // والقائمةُ تُعيد قراءتَها عليه. ولو سقطت تلك الوصلةُ لَرجع صاحبُه من
      // إلغاءٍ تمَّ فعلاً إلى بطاقةٍ تقول إنّ حجزَه ما زال مؤكَّداً — يظنّ
      // أنّ الإلغاء لم يقع فيُعيده.
      _phone(tester);
      final saved = [...demoBookings];
      addTearDown(() => demoBookings = saved);

      await tester.pumpWidget(_wrap(MyBookingsScreen(session: _customer())));
      await _settle(tester);

      // **وبمفتاحها** لا بنصٍّ فيها: نصُّ العنوان يأتي من بيانات العرض وقد
      // يتبدّل، والمفتاحُ يقول أيَّ ودجةٍ قُصدت.
      final card = find.byWidgetPredicate(
        (w) => w is Column && '${w.key}'.contains('booking-card-'),
      );
      await tester.tap(card.first);
      await _settle(tester);
      expect(find.byType(BookingDetailScreen), findsOneWidget);

      // يُلغى من الشاشة، ويُؤكَّد في الحوار.
      await _toEnd(tester);
      await tester.tap(find.byKey(const ValueKey('booking-cancel')));
      await _settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'إلغاء الحجز').last);
      await _settle(tester);

      // رجعنا إلى القائمة، **وفيها حالةُ الحجز الجديدة**.
      expect(find.byType(BookingDetailScreen), findsNothing,
          reason: 'الشاشةُ لم تُغلق بعد الإلغاء');
      expect(find.text('ملغي'), findsWidgets,
          reason: 'القائمةُ لم تُعد قراءتَها — تعرض حالةً قديمة');
    });

    testWidgets('**وتُفتح بالضغط وتقول إنّها تُفتح**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(MyBookingsScreen(session: _customer())));
      await _settle(tester);

      // والسهمُ `chevron_right` في تطبيقٍ عربيّ: الأيقونةُ تنقلب مع اللغة
      // بنفسها، فالمكتوبُ صورتُها اللاتينيّة. (يُنظر `chevron_direction_test`.)
      expect(find.byIcon(Icons.chevron_right), findsWidgets,
          reason: 'لا سهمَ يقول إنّ البطاقة تُفتح');

      // **وتُضغط البطاقةُ نفسُها بمفتاحها** لا نصٌّ فيها: نصُّ العنوان يأتي
      // من بيانات العرض وقد يتبدّل، والمفتاحُ يقول أيَّ ودجةٍ قُصدت.
      // **وبمفتاحها** لا بنصٍّ فيها: نصُّ العنوان يأتي من بيانات العرض وقد
      // يتبدّل، والمفتاحُ يقول أيَّ ودجةٍ قُصدت.
      final card = find.byWidgetPredicate(
        (w) => w is Column && '${w.key}'.contains('booking-card-'),
      );
      expect(card, findsWidgets, reason: 'لا بطاقةَ حجزٍ في القائمة');
      await tester.tap(card.first);
      await _settle(tester);

      expect(find.byType(BookingDetailScreen), findsOneWidget,
          reason: 'الضغطةُ على البطاقة لم تفتح التفصيل');
    });
  });
}
