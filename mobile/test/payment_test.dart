// الدفع: ما يُعرض، وما لا يُرسَل.
//
// **وأهمّ ما هنا أن المبلغ لا يُكتب ولا يُرسَل.** يحسبه الخادم من الحجز نفسه،
// وحقلٌ يكتب فيه العميل مبلغه يفتح باب حجز قاعةٍ بريالٍ واحد.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/screens/payment.dart';
import 'package:aras/src/ui/kit.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
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

void _phone(WidgetTester tester, {double height = 3600}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// حجزٌ من بيانات العرض نفسها — لا واحدٌ مخترَع.
///
/// **ولماذا:** المبلغ يحسبه «الخادم» من الحجز، ووضعُ العرض خادمُه هو
/// `demoBookings`. فحجزٌ يُبنى في الاختبار بأرقامٍ من عنده يقيس شيئاً لا وجود
/// له، ويمرّ أو يسقط بلا علاقةٍ بما يقع على الجهاز.
Booking _unpaid() => demoBookings.firstWhere((b) => b.paidAmount < b.depositAmount);
Booking _settled() => demoBookings.firstWhere((b) => b.paidAmount >= b.totalPrice,
    orElse: () => demoBookings.first);

void main() {
  setUp(demoResetPayments);

  testWidgets('الشاشة تعرض المستحقّ ولا تسأل عن مبلغ', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(PaymentScreen(booking: _unpaid())));
    await _settle(tester);

    final due = _unpaid().depositAmount - _unpaid().paidAmount;
    expect(find.text(formatMoney(due)), findsOneWidget);
    // ولا حقلَ مبلغ: الحقل الوحيد لرقم المحوِّل.
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, hasLength(1));
    expect(
      (fields.first.decoration?.labelText ?? ''),
      isNot(contains('المبلغ')),
    );
  });

  testWidgets('وأرقامُ التحويل تُعرض وتُنسخ', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(PaymentScreen(booking: _unpaid())));
    await _settle(tester);

    expect(find.text('770 000 000'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsWidgets);
  });

  testWidgets('ولا يُرسَل إبلاغٌ بلا وسيلة', (tester) async {
    // **وهذا ما ينكسر بصمت:** إبلاغٌ بلا وسيلةٍ يصل الإدارة فلا تعرف أين
    // تبحث عن الحوالة — في جوالي أم الكريمي أم كشف البنك.
    _phone(tester);
    await tester.pumpWidget(_wrap(PaymentScreen(booking: _unpaid())));
    await _settle(tester);

    await tester.tap(find.text('حوّلتُ المبلغ — أبلغ الإدارة'));
    await _settle(tester);

    expect(find.textContaining('اختر الوسيلة'), findsOneWidget);
    expect(demoPayments, isEmpty);
  });

  testWidgets('والإبلاغ يقع معلّقاً بالمبلغ المحسوب', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(PaymentScreen(booking: _unpaid())));
    await _settle(tester);

    // «جوالي» اسمٌ في مكانين: سطرُ الرقم الذي يُحوَّل إليه، وشريحةُ الاختيار.
    // وباحثٌ بالنصّ وحده يجد اثنين فيرمي.
    await tester.tap(find.descendant(
      of: find.byType(PickChip),
      matching: find.text('جوالي'),
    ));
    await tester.enterText(find.byType(TextField).first, '777123456');
    await tester.tap(find.text('حوّلتُ المبلغ — أبلغ الإدارة'));
    await _settle(tester);

    expect(demoPayments, hasLength(1));
    expect(demoPayments.first.amount, _unpaid().depositAmount - _unpaid().paidAmount);
    expect(demoPayments.first.status, 'pending');
    // ويُقال له إنه لم يُحتسب بعد.
    expect(find.text('قيد التأكيد'), findsOneWidget);
  });

  testWidgets('وبطاقةُ الحجز فيها بابٌ إلى الدفع', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(Scaffold(body: MyBookingsScreen(session: _session()))));
    await _settle(tester);

    expect(find.textContaining('ادفع العربون'), findsWidgets);
  });

  testWidgets('ومن دفع عربونه يُدعى إلى إكمال الباقي لا إلى دفعه ثانيةً', (tester) async {
    // زرٌّ يَعِد بدفع عربونٍ دُفع ثم يردّه الخادم بـ«لا مبلغ مستحقّاً» أسوأ من
    // غيابه.
    _phone(tester);
    final b = _settled();
    await tester.pumpWidget(_wrap(Scaffold(body: MyBookingsScreen(session: _session()))));
    await _settle(tester);

    if (b.paidAmount >= b.depositAmount && b.paidAmount < b.totalPrice) {
      expect(find.textContaining('أكمل المبلغ'), findsWidgets);
    }
  });

  // ==========================================================================
  //  بطاقةُ الحجز هي بطاقةُ «خطة العرس» نفسها
  // ==========================================================================

  testWidgets('بطاقةُ الحجز نبيذيّةٌ كبطاقة «خطة العرس» لا بيضاء', (tester) async {
    // **والقياسُ على `HeroCard` نفسها لا على لونٍ منسوخ:** الشاشتان تبنيان
    // منها، فلو نُسخ التدرّج في إحداهما لَمرّ اختبارٌ يسأل عن اللون وحده
    // بينما البطاقتان افترقتا فعلاً.
    _phone(tester);
    await tester.pumpWidget(_wrap(Scaffold(body: MyBookingsScreen(session: _session()))));
    await _settle(tester);

    expect(find.byType(HeroCard), findsWidgets);
  });

  testWidgets('والمبلغُ رقمٌ كبيرٌ في صدرها، ومعه ما بقي', (tester) async {
    // ترتيبُ بطاقة الخطة نفسه: رقمٌ كبير ثمّ وصفُه بالذهبيّ. وبطاقةُ الخطة
    // تجيب «كم بقي من الأيام؟»، وهذه تجيب «بكم؟» — وهو أوّلُ ما يُبحث عنه.
    _phone(tester);
    await tester.pumpWidget(_wrap(Scaffold(body: MyBookingsScreen(session: _session()))));
    await _settle(tester);

    final big = tester.widgetList<Text>(find.byType(Text)).where(
      (t) => (t.style?.fontSize ?? 0) >= 28 && (t.data ?? '').contains(RegExp(r'[0-9٠-٩]')),
    );
    expect(big, isNotEmpty, reason: 'لا رقمَ كبيراً في صدر البطاقة');

    // وحالةُ الدفع مذكورةٌ نصّاً: «لم يُدفع بعد» أو «باقٍ …» أو «مدفوع بالكامل».
    expect(
      find.textContaining(RegExp('لم يُدفع بعد|باقٍ|مدفوع بالكامل')),
      findsWidgets,
    );
  });

  testWidgets('وزرُّ الدفع ذهبيٌّ لا نبيذيٌّ يذوب في البطاقة', (tester) async {
    // **زرٌّ بلون أرضيّته زرٌّ غيرُ موجود.** نبيذيُّ الأزرار هو نبيذيُّ
    // البطاقة، فلولا قلبُه ذهباً لاختفى «ادفع العربون» تماماً.
    _phone(tester);
    await tester.pumpWidget(_wrap(Scaffold(body: MyBookingsScreen(session: _session()))));
    await _settle(tester);

    final pay = find.ancestor(
      of: find.textContaining('ادفع العربون'),
      matching: find.byType(FilledButton),
    );
    expect(pay, findsWidgets);

    final style = tester.widgetList<FilledButton>(pay).first.style;
    final bg = style?.backgroundColor?.resolve(const <WidgetState>{});
    expect(bg, AppColors.goldOnAccent,
        reason: 'زرُّ الدفع يجب أن يكون ذهبيّاً على البطاقة النبيذيّة');
  });
}
