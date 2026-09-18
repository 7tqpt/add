// موضعُ شارة الحال في رأس ملفّ المزوّد — جنبَ المحافظة لا سطراً تحتها.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «كلمة موثّق أخذت مساحة، أريدها جنب المحافظة». والرأسُ يقصُر بذلك سطراً
// فترتفع الأبوابُ تحته.
//
// ── ويُقاس الموضعُ بالهندسة لا بالوجود ──────────────────────────────────────
//
// **وجودُ الشارة في الشجرة لا يقول أين هي**: شارةٌ في سطرها تحت المحافظة
// وشارةٌ جنبَها كلتاهما «موجودة». فتُقاس **بالبكسل**: أتشتركان في ارتفاعٍ
// واحد؟ وهو الفرقُ الذي طُلب بعينه.
//
// ── وأطولُ حالٍ لا أقصرُها ──────────────────────────────────────────────────
//
// «موثّق» كلمةٌ قصيرة، و«قيد المراجعة» ضِعفُها — وهي حالُ كلِّ مزوّدٍ جديدٍ
// قبل قبوله. فلو قِيست القصيرةُ وحدَها لَمرّ ما ينكسر عند أوّلِ من يفتح
// شاشته.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
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
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Widget _head({
  required String subtitle,
  required String badge,
  bool besideTitle = false,
}) => ProfileHeader(
  avatar: const SizedBox(width: 92, height: 92),
  title: 'قاعة التاج',
  subtitle: subtitle,
  badge: badge,
  badgeBesideTitle: besideTitle,
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// أيقف النصّان في سطرٍ واحد؟ — يُقاس بتقاطع ارتفاعيهما.
bool _sameLine(WidgetTester tester, String a, String b) {
  final ra = tester.getRect(find.text(a));
  final rb = tester.getRect(find.text(b));
  return ra.top < rb.bottom && rb.top < ra.bottom;
}

void main() {
  group('الشارةُ جنبَ المحافظة', () {
    testWidgets('**«موثّق» في سطر المحافظة نفسِه**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(_head(subtitle: 'أمانة العاصمة', badge: 'موثّق')));
      await tester.pumpAndSettle();

      expect(_sameLine(tester, 'أمانة العاصمة', 'موثّق'), isTrue,
          reason: 'الشارةُ ما زالت في سطرٍ تحت المحافظة');
      expect(tester.takeException(), isNull);
    });

    testWidgets('**وأطولُ حالٍ كذلك — «قيد المراجعة»**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _wrap(_head(subtitle: 'أمانة العاصمة', badge: 'قيد المراجعة')),
      );
      await tester.pumpAndSettle();

      expect(_sameLine(tester, 'أمانة العاصمة', 'قيد المراجعة'), isTrue);
      // **ولا تنكسر الشاشةُ بها** — وهي حالُ كلّ مزوّدٍ جديد.
      expect(tester.takeException(), isNull,
          reason: 'انكسر الرسمُ بأطول حال');
    });

    testWidgets('**وتُقَصّ المحافظةُ لا الشارة إن ضاق العرض**', (tester) async {
      // الحالُ هي المعلومة، والمحافظةَ يعرفها صاحبُها. ولو قُصّت الشارةُ
      // لَقرأ «قيد المرا…» ولم يعرف أمقبولٌ هو أم لا.
      tester.view.physicalSize = const Size(620, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(_head(subtitle: 'محافظة حضرموت الساحلية وواديها', badge: 'قيد المراجعة')),
      );
      await tester.pumpAndSettle();

      expect(find.text('قيد المراجعة'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'فاض العرضُ بها');
    });
  });

  group('وما لم يتغيّر', () {
    testWidgets('**ومن لا محافظةَ له تبقى شارتُه في سطرها**', (tester) async {
      // لا تُرفع إلى سطرٍ غيرِ موجود.
      _phone(tester);
      await tester.pumpWidget(_wrap(_head(subtitle: '', badge: 'موثّق')));
      await tester.pumpAndSettle();

      expect(find.text('موثّق'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('**وشارةُ «حسابي» تبقى يسارَ الاسم لا تنزل**', (tester) async {
      // شاشتان تتشاركان `ProfileHeader`، وتغييرُ إحداهما لا يمسّ الأخرى.
      _phone(tester);
      await tester.pumpWidget(
        _wrap(_head(subtitle: 'ayman@sdd.company', badge: 'عريس', besideTitle: true)),
      );
      await tester.pumpAndSettle();

      expect(_sameLine(tester, 'قاعة التاج', 'عريس'), isTrue,
          reason: 'نزلت شارةُ «حسابي» عن سطر الاسم');
      expect(_sameLine(tester, 'ayman@sdd.company', 'عريس'), isFalse,
          reason: 'نزلت الشارةُ إلى سطر البريد');
    });
  });
}
