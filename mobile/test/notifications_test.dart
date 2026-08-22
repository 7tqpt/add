// صندوق الإشعارات.
//
// ولا Firebase هنا: `Push.start()` تُستدعى من القشرة، و`initializeApp` ترمي
// في بيئة الاختبار فتُلتقط ويبقى الدفع مطفأً — وهي الحال نفسها التي يقع فيها
// كلُّ من بنى التطبيق بلا مشروع Firebase. أي أن ما يُختبر هو المسار الافتراضي
// لا بديلٌ مصطنع عنه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/push.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/chat.dart';
import 'package:aras/src/screens/customer_shell.dart';
import 'package:aras/src/screens/notifications.dart';
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

void _phone(WidgetTester tester, {double height = 2400}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

void main() {
  setUp(() {
    demoResetNotifications();
    demoResetChat();
  });

  group('الصندوق', () {
    Widget inbox({void Function(BuildContext, AppNotification)? onOpen}) =>
        NotificationsScreen(onOpen: onOpen ?? (_, _) {});

    testWidgets('يعرض ما كُتب فيه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(inbox()));
      await _settle(tester);

      expect(find.text('تم تأكيد حجزك'), findsOneWidget);
      expect(find.text('تم استلام الدفعة'), findsOneWidget);
      expect(find.text('قاعة التاج'), findsOneWidget);
    });

    testWidgets('ولكلّ نوعٍ أيقونته ولونه', (tester) async {
      // أيقونةٌ واحدة لعشرين سطراً تجعل الصندوق كتلةً تُبحث بالقراءة.
      final kinds = NotificationKind.values;
      final icons = kinds.map((k) => notificationLook(k).icon).toSet();
      expect(icons.length, kinds.length);
      _phone(tester);
      await tester.pumpWidget(_wrap(inbox()));
      await _settle(tester);
      expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);
      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    });

    testWidgets('و«علّم الكلّ» يظهر بعدد الجديد ويصفّره', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(inbox()));
      await _settle(tester);

      expect(find.text('2 جديد'), findsOneWidget);
      await tester.tap(find.text('علّم الكلّ مقروءاً'));
      await _settle(tester);

      expect(demoNotificationList().where((n) => n.isUnread), isEmpty);
      // والزرّ يغيب حين لا شيء يُعلَّم: زرٌّ لا أثر لضغطه يُوهم بعطب.
      expect(find.text('علّم الكلّ مقروءاً'), findsNothing);
    });

    testWidgets('والضغط يُعلّم المضغوط وحده', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(inbox()));
      await _settle(tester);

      await tester.tap(find.text('تم تأكيد حجزك'));
      await _settle(tester);

      final rows = demoNotificationList();
      expect(rows.firstWhere((n) => n.id == 'n2').isUnread, isFalse);
      expect(rows.firstWhere((n) => n.id == 'n1').isUnread, isTrue);
    });

    testWidgets('وصندوقٌ فارغ يقول ما الذي يصله', (tester) async {
      demoNotifications = [];
      _phone(tester);
      await tester.pumpWidget(_wrap(inbox()));
      await _settle(tester);

      expect(find.text('لا إشعارات'), findsOneWidget);
      expect(find.textContaining('حجوزاتك ومدفوعاتك'), findsOneWidget);
    });
  });

  group('الجرس والوجهة', () {
    testWidgets('الجرس في الشريط العلوي بعدد الجديد', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(CustomerShell(session: _session())));
      await _settle(tester);

      expect(find.byType(BellIconButton), findsOneWidget);
      expect(tester.widget<BellIconButton>(find.byType(BellIconButton)).unread, 2);
      // والشريط السفلي بحاله: خمسةٌ لا ستّة.
      expect(tester.widget<GlassNavBar>(find.byType(GlassNavBar)).items.length, 5);
    });

    testWidgets('وضغطُه يفتح الصندوق', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(CustomerShell(session: _session())));
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await _settle(tester);
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('وإشعار الرسالة يُفتح على خيطه لا على القائمة', (tester) async {
      // من ضغط إشعاراً باسم «قاعة التاج» يريد ما قالته القاعة، لا قائمةً
      // يبحث فيها عنها.
      _phone(tester);
      await tester.pumpWidget(_wrap(CustomerShell(session: _session())));
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await _settle(tester);
      await tester.tap(find.text('قاعة التاج'));
      await _settle(tester);

      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('وإشعار الحجز ينقل إلى تبويب الحجوزات', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(CustomerShell(session: _session())));
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await _settle(tester);
      await tester.tap(find.text('تم تأكيد حجزك'));
      await _settle(tester);

      expect(find.byType(NotificationsScreen), findsNothing);
      expect(tester.widget<GlassNavBar>(find.byType(GlassNavBar)).index, 1);
    });
  });

  group('الدفع', () {
    test('مطفأٌ بلا Firebase، ولا يُسقط شيئاً', () async {
      // هذه هي الحال الافتراضية لكل من بنى التطبيق بلا `google-services.json`:
      // الجرس يعمل والصندوق يمتلئ، ولا يصل الجوال شيءٌ وهو مغلق.
      await Push.start();
      expect(Push.active, isFalse);
      expect(Push.token, isNull);
      await Push.stop();
    });
  });
}
