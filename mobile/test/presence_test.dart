// الحضور: «متّصل الآن» و«آخر ظهور».
//
// **وأصلُ هذا العمل علّةٌ لا ميزة.** `app_users.last_seen_at` كان في المخطَّط
// منذ أوّل يوم ولا سطرَ في التطبيق كلِّه يكتبه — واللوحةُ تقرؤه في ثلاثة
// مواضع. وأخطرُها استهدافُ البثّ: شرطُ «غير نشِط» هو `last_seen_at is null or
// … < now() - 30 days`، وعمودٌ فارغٌ لكلِّ مستخدمٍ يعني أنّ حملةً تُبعث إلى
// «غير النشطين» تذهب إلى **الجميع**. فالنبضةُ هنا تُصلح ثلاثةَ مواضع في
// اللوحة قبل أن تُظهر سطراً واحداً في التطبيق.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/presence.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/chat.dart';
import 'package:aras/src/screens/customer_shell.dart';
import 'package:aras/src/screens/provider_public.dart';
import 'package:aras/src/screens/provider_shell.dart';
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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// اللونُ المرسومُ فعلاً لنصٍّ بعينه — لا اللونُ المكتوب في الثابت.
Color _colourOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

void main() {
  // ==========================================================================
  //  ١) متى يُعدّ صاحبُه متّصلاً
  // ==========================================================================
  group('مهلةُ الاتّصال', () {
    test('ومن لا ظهورَ له مسجَّلٌ ليس متّصلاً', () {
      expect(Presence.isOnline(null), isFalse);
    });

    test('والنابضُ الآن متّصل', () {
      expect(Presence.isOnline(DateTime.now()), isTrue);
    });

    test('وتسعون ثانيةً تبقى اتّصالاً — نبضةٌ سقطت لا مستخدمٌ خرج', () {
      final at = DateTime.now().subtract(const Duration(seconds: 90));
      expect(Presence.isOnline(at), isTrue);
    });

    test('وثلاثُ دقائقَ تُخرجه', () {
      final at = DateTime.now().subtract(const Duration(minutes: 3));
      expect(Presence.isOnline(at), isFalse);
    });

    test('وساعةُ الخادم إن سبقت ساعةَ الجهاز فصاحبُها متّصلٌ لا غائبٌ في المستقبل', () {
      final at = DateTime.now().add(const Duration(seconds: 20));
      expect(Presence.isOnline(at), isTrue);
    });

    // والقاعدةُ نفسُها لا مثالٌ عليها: المهلةُ ضِعفُ النبضة لتحتمل سقوطَ
    // واحدة. ولو سُوّيت بها لَومض السطرُ بين حالين أمام مستخدمٍ لم يغادر.
    test('والمهلةُ ضِعفُ النبضة', () {
      expect(Presence.window, Presence.beat * 2);
    });
  });

  // ==========================================================================
  //  ٢) سطرُ الحضور
  // ==========================================================================
  group('سطرُ الحضور', () {
    testWidgets('ومن لا ظهورَ له لا يُرسم له سطرٌ أصلاً', (tester) async {
      await tester.pumpWidget(_wrap(const Scaffold(body: PresenceLine(lastSeen: null))));
      await tester.pump();

      expect(find.textContaining('آخر ظهور'), findsNothing);
      expect(find.text('متّصل الآن'), findsNothing);
    });

    testWidgets('والمتّصلُ يُقال بنصٍّ ونقطةٍ معاً لا بنقطةٍ وحدها', (tester) async {
      await tester.pumpWidget(
        _wrap(Scaffold(body: PresenceLine(lastSeen: DateTime.now()))),
      );
      await tester.pump();

      expect(find.text('متّصل الآن'), findsOneWidget);

      // النقطة: حاويةٌ دائريّةٌ خضراء — زينةٌ تسبق الخبر، ومن لا يميّز
      // الأخضرَ يقرأ النصَّ كاملاً بجوارها.
      final dot = tester.widget<Container>(
        find.descendant(of: find.byType(PresenceLine), matching: find.byType(Container)),
      );
      final box = dot.decoration! as BoxDecoration;
      expect(box.shape, BoxShape.circle);
      expect(box.color, AppColors.good);
    });

    testWidgets('وغيرُ المتّصل يُقال بآخر ظهوره لا بـ«غير متّصل»', (tester) async {
      final at = DateTime.now().subtract(const Duration(hours: 3));
      await tester.pumpWidget(_wrap(Scaffold(body: PresenceLine(lastSeen: at))));
      await tester.pump();

      expect(find.textContaining('آخر ظهور'), findsOneWidget);
      // **وهذه هي الغاية.** «غير متّصل» تحت اسم صاحب القاعة تقول للعميل «لن
      // يردّ» — وهو قد يردّ بعد دقيقة. و«آخر ظهور منذ ٣ ساعات» تقول ما جرى
      // بلا حكمٍ على ما سيجري.
      expect(find.textContaining('غير متّصل'), findsNothing);
      expect(find.textContaining('غير متصل'), findsNothing);
    });

    testWidgets('وأخضرُ «متّصل الآن» يُقرأ على أرضيّة الصفحة', (tester) async {
      await tester.pumpWidget(
        _wrap(Scaffold(body: PresenceLine(lastSeen: DateTime.now()))),
      );
      await tester.pump();

      // من اللون المرسوم لا من الثابت: لو بُدّل اللونُ في السطر بقي الثابتُ
      // كما هو ومرّ الاختبار على لونٍ لا يُرسم.
      final green = _colourOf(tester, 'متّصل الآن');
      expect(_ratio(green, AppColors.page), greaterThanOrEqualTo(4.5));
      expect(_ratio(green, AppColors.surface), greaterThanOrEqualTo(4.5));
    });
  });

  // ==========================================================================
  //  ٣) النبضةُ نفسُها — أن تُكتب أصلاً
  // ==========================================================================
  //
  //  وهذا الضابطُ هو الأهمّ: العلّةُ الأصليّة لم تكن في سطرٍ يُعرض، بل في
  //  عمودٍ لا يُكتب. ولو حُذفت `Presence.start()` من القشرة لَعادت العلّةُ
  //  كما كانت — وكلُّ اختبارٍ غيرُه يبقى أخضر.
  group('نبضةُ الحضور', () {
    testWidgets('تبدأ مع قشرة العميل وتقف بزوالها', (tester) async {
      _phone(tester);
      expect(Presence.running, isFalse);

      await tester.pumpWidget(_wrap(CustomerShell(session: Session())));
      await _settle(tester);
      expect(Presence.running, isTrue);

      await tester.pumpWidget(_wrap(const Scaffold(body: SizedBox())));
      await _settle(tester);
      expect(Presence.running, isFalse);
    });

    testWidgets('وتبدأ مع قشرة المزوّد كذلك', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(ProviderShell(session: Session())));
      await _settle(tester);
      expect(Presence.running, isTrue);

      await tester.pumpWidget(_wrap(const Scaffold(body: SizedBox())));
      await _settle(tester);
    });
  });

  // ==========================================================================
  //  ٤) في الدردشة
  // ==========================================================================
  group('حضورُ الطرف الآخر في الدردشة', () {
    Widget thread() => const ChatScreen(
          conversationId: 'cv1',
          otherName: 'قاعة التاج',
          mySide: ChatSide.customer,
        );

    testWidgets('الاسمُ وتحته الحضور', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(thread()));
      await _settle(tester);

      expect(find.text('قاعة التاج'), findsOneWidget);
      expect(find.text('متّصل الآن'), findsOneWidget);

      // وتحته لا بجواره: عمودٌ في عنوان الشريط.
      final name = tester.getCenter(find.text('قاعة التاج'));
      final line = tester.getCenter(find.text('متّصل الآن'));
      expect(line.dy, greaterThan(name.dy));
    });

    testWidgets('ولا يبقى مؤقّتٌ يسأل عن حضورِ شاشةٍ زالت', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(thread()));
      await _settle(tester);

      // ولو بقي لَسقط الاختبارُ عند التفكيك بـ«A Timer is still pending».
      await tester.pumpWidget(_wrap(const Scaffold(body: SizedBox())));
      await _settle(tester);
    });
  });

  // ==========================================================================
  //  ٥) في الملفّ العامّ
  // ==========================================================================
  group('حضورُ المزوّد في ملفّه', () {
    testWidgets('آخرُ ظهوره تحت اسمه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
      await _settle(tester);

      expect(find.textContaining('آخر ظهور'), findsOneWidget);
    });

    testWidgets('وسقوطُ الحضورِ لا يُسقط الملفّ', (tester) async {
      _phone(tester);
      // مزوّدٌ بلا حضورٍ في وضع العرض؟ لا يوجد — فيُقاس السطرُ وحدَه:
      // `PresenceLine` بـ`null` لا يرسم شيئاً، والشاشةُ حولَه تبقى.
      await tester.pumpWidget(
        _wrap(const Scaffold(
          body: Column(children: [Text('قاعة التاج'), PresenceLine(lastSeen: null)]),
        )),
      );
      await tester.pump();

      expect(find.text('قاعة التاج'), findsOneWidget);
    });
  });
}
