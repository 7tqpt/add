// تذكرة خدمة العملاء: ترتيبُ الرسائل، وأين تهبط الشاشة.
//
// وهي محادثةٌ ثانية في التطبيق غير محادثة المزوّد، فلها العطبُ نفسه ولها
// حارسٌ خاصّ: `api_order_test` يحرس الاستعلام، وهذا يحرس ما يقع على الشاشة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/ticket.dart';

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

SupportTicket _ticket() => SupportTicket(
  id: 't1',
  reference: 'SUP-2026-000118',
  subject: 'خُصم المبلغ ولم يظهر الحجز',
  status: 'waiting_customer',
  lastMessageAt: DateTime.now().toIso8601String(),
);

void main() {
  testWidgets('شكواي أعلى وردُّ الإدارة أسفل', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(TicketScreen(ticket: _ticket())));
    await _settle(tester);

    final mine = tester.getCenter(find.textContaining('حوّلت العربون')).dy;
    final theirs = tester.getCenter(find.textContaining('راجعنا سجل البوابة')).dy;
    expect(mine, lessThan(theirs));
  });

  testWidgets('والشاشة تهبط على آخر رسالة لا على أوّلها', (tester) async {
    // **وهذا ما ينكسر بصمت:** التذكرة تُقرأ من أعلى إلى أسفل، فمن فتحها بلا
    // هبوطٍ وجد **شكواه هو** أمامه وردَّ الإدارة تحت الطيّة — وهو جوابُ ما
    // فتح التذكرة لأجله.
    //
    // والشاشة هنا قصيرةٌ عمداً: على شاشةٍ طويلة يظهر كلُّ شيء فيمرّ الاختبار
    // ولو لم يهبط شيء.
    demoTicketMessages = [
      for (var i = 0; i < 12; i++)
        SupportMessage(
          id: 'tm$i',
          author: i.isEven ? 'customer' : 'admin',
          authorName: i.isEven ? 'أحمد' : 'خدمة العملاء',
          body: i == 11 ? 'آخرُ ما قيل' : 'رسالةٌ رقم $i من الرسائل الطويلة نسبياً',
          createdAt: DateTime.now().subtract(Duration(hours: 12 - i)).toIso8601String(),
        ),
    ];
    addTearDown(demoResetTicketMessages);

    tester.view.physicalSize = const Size(1080, 1400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(TicketScreen(ticket: _ticket())));
    await _settle(tester);

    final last = find.text('آخرُ ما قيل');
    expect(last, findsOneWidget, reason: 'آخر رسالةٍ لم تُبنَ أصلاً');

    final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final y = tester.getCenter(last).dy;
    expect(y, greaterThan(0));
    expect(y, lessThan(screen), reason: 'آخر رسالةٍ خارج الشاشة — لم تهبط');
  });
}
