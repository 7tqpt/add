// المحادثة: القائمة والخيط.
//
// ولا بثَّ حيّاً هنا: `Api.conversationStream` تعيد `null` بلا Supabase،
// فتسلك الشاشة طريق القراءة الواحدة — وهو الطريق نفسه الذي تسلكه على قاعدةٍ
// لم يُضَف جدولها إلى نشرة البثّ. أي أن ما يُختبر حالٌ حقيقية لا بديلٌ عنها.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/chat.dart';
import 'package:aras/src/screens/conversations.dart';
import 'package:aras/src/screens/customer_shell.dart';
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
  setUp(demoResetChat);

  test('ختم الوقت على فقاعتي يُقرأ', () {
    // القياس هنا لا في ورقةٍ جانبية: شفافيةٌ تُخفَّض غداً تمرّ صامتة. وقد
    // كانت ‎٠٫٧٥‎ فأعطت ‎٤٫٤٨:١‎ — تحت العتبة، ولم يظهر ذلك إلّا بالقياس.
    double lin(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
    double lum(Color c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);

    const bg = AppColors.accent;
    final stamp = Color.from(
      alpha: 1,
      red: chatStampAlpha * 1.0 + (1 - chatStampAlpha) * bg.r,
      green: chatStampAlpha * 1.0 + (1 - chatStampAlpha) * bg.g,
      blue: chatStampAlpha * 1.0 + (1 - chatStampAlpha) * bg.b,
    );
    final a = lum(stamp);
    final b = lum(bg);
    final ratio = (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
    expect(ratio, greaterThanOrEqualTo(4.5), reason: '${ratio.toStringAsFixed(2)}:1');
  });

  group('قائمة المحادثات', () {
    testWidgets('تعرض الطرف الآخر وآخر ما قيل', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const ConversationsScreen()));
      await _settle(tester);

      expect(find.text('قاعة التاج'), findsOneWidget);
      expect(find.text('مطبخ الأصالة'), findsOneWidget);
      expect(find.textContaining('وتشمل التنسيق والإضاءة'), findsOneWidget);
    });

    testWidgets('و«أنت:» أمام كلامي أنا', (tester) async {
      // بلا هذه الكلمة يبدو آخرُ ما قلتُه وكأنه ردٌّ منه، فأنتظر جواباً وصل
      // ولم يصل.
      _phone(tester);
      await tester.pumpWidget(_wrap(const ConversationsScreen()));
      await _settle(tester);

      expect(find.textContaining('أنت: كم سعر مندي'), findsOneWidget);
      expect(find.textContaining('أنت: وتشمل التنسيق'), findsNothing);
    });

    testWidgets('وحبّةُ ما لم يُقرأ بعددها', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const ConversationsScreen()));
      await _settle(tester);

      // رسالتان من القاعة لم تُقرآ، ولا شيء في خيط المطبخ.
      expect(find.byType(UnreadDot), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('والقائمة الفارغة تقول من أين يبدأ', (tester) async {
      // شاشةٌ بيضاء تقول «لا شيء هنا»؛ وهذه تقول «افتح خدمةً واضغط راسل».
      _threadsEmpty();
      _phone(tester);
      await tester.pumpWidget(_wrap(const ConversationsScreen()));
      await _settle(tester);

      expect(find.text('لا محادثات بعد'), findsOneWidget);
      expect(find.textContaining('راسل مقدّم الخدمة'), findsOneWidget);
    });
  });

  group('خيط المحادثة', () {
    Widget thread() => const ChatScreen(
      conversationId: 'cv1',
      otherName: 'قاعة التاج',
      mySide: ChatSide.customer,
    );

    testWidgets('الرسائل بترتيبها', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(thread()));
      await _settle(tester);

      expect(find.textContaining('القاعة متاحة يوم'), findsOneWidget);
      expect(find.textContaining('العربون ٣٠٪'), findsOneWidget);
    });

    testWidgets('الأقدم أعلى والأحدث أسفل', (tester) async {
      // حارسُ الجهة الأخرى: `api_order_test` يحرس ترتيبَ الاستعلام، وهذا
      // يحرس ترتيبَ الرسم. فلو عُكس بـ`reverse: true` أو `.reversed` في
      // الشاشة لعاد الخيط مقلوباً وإن كان الاستعلام صعودياً.
      _phone(tester);
      await tester.pumpWidget(_wrap(thread()));
      await _settle(tester);

      final oldest = tester.getCenter(find.textContaining('القاعة متاحة يوم')).dy;
      final newest = tester.getCenter(find.textContaining('وتشمل التنسيق')).dy;
      expect(oldest, lessThan(newest));
    });

    testWidgets('وكلامي في جهةٍ وكلامه في الأخرى', (tester) async {
      // الجهة علامةٌ ثانية غير اللون: من لا يفرّق الألوان يعرف صاحب الرسالة
      // من موضعها.
      _phone(tester);
      await tester.pumpWidget(_wrap(thread()));
      await _settle(tester);

      final mine = tester.getCenter(find.textContaining('القاعة متاحة يوم'));
      final theirs = tester.getCenter(find.textContaining('العربون ٣٠٪'));
      expect(mine.dx, lessThan(theirs.dx));
    });

    testWidgets('وما يُرسَل يظهر في مكانه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(thread()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'هل يوجد موقف سيارات؟');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await _settle(tester);

      expect(find.text('هل يوجد موقف سيارات؟'), findsOneWidget);
      // والحقل يُفرَّغ: نصٌّ يبقى بعد الإرسال يُرسَل مرّتين بضغطةٍ ثانية.
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
    });

    testWidgets('والفارغُ لا يُرسَل', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(thread()));
      await _settle(tester);

      final before = demoMessagesOf('cv1').length;
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await _settle(tester);

      expect(demoMessagesOf('cv1').length, before);
    });

    testWidgets('وخيطٌ جديد يدعو إلى البدء لا يعرض فراغاً', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _wrap(const ChatScreen(
          conversationId: 'cv-none',
          otherName: 'قاعة أخرى',
          mySide: ChatSide.customer,
        )),
      );
      await _settle(tester);
      expect(find.text('ابدأ الحديث'), findsOneWidget);
    });

    testWidgets('وفتحُه يُعلّمه مقروءاً', (tester) async {
      _phone(tester);
      expect(demoConversationList().firstWhere((c) => c.id == 'cv1').unreadCount, 2);

      await tester.pumpWidget(_wrap(thread()));
      await _settle(tester);

      expect(demoConversationList().firstWhere((c) => c.id == 'cv1').unreadCount, 0);
    });
  });

  group('المدخل', () {
    testWidgets('أيقونة المحادثات في شريط العميل، وعليها العدد', (tester) async {
      // في الشريط العلوي لا السفلي: بنوده الخمسة محدَّدة، وسادسٌ يضيّقها كلَّها.
      _phone(tester);
      await tester.pumpWidget(_wrap(CustomerShell(session: _session())));
      await _settle(tester);

      expect(find.byType(ChatIconButton), findsOneWidget);
      expect(find.byType(GlassNavBar), findsOneWidget);
      expect(
        tester.widget<GlassNavBar>(find.byType(GlassNavBar)).items.length,
        5,
      );
      expect(tester.widget<ChatIconButton>(find.byType(ChatIconButton)).unread, 2);
    });

    testWidgets('وضغطُها يفتح القائمة', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(CustomerShell(session: _session())));
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.forum_outlined));
      await _settle(tester);
      expect(find.byType(ConversationsScreen), findsOneWidget);
    });
  });
}

/// يُفرغ خيوط وضع العرض — لاختبار الحال التي يبدأ منها كل مستخدمٍ جديد.
void _threadsEmpty() {
  demoResetChat();
  for (final c in demoConversationList()) {
    demoDropThread(c.id);
  }
}
