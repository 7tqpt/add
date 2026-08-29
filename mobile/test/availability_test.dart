// التقويم: ما يُفتح وما لا يُفتح.
//
// **وأهمّ ما هنا أن اليومين ليسا سواء.** يومٌ أغلقته القاعدة بحجزٍ مؤكّد لا
// يفتحه صاحبه — ولو فُتح لأمكن أن يقع عرسان في ليلة. وشاشةٌ تعرض له زرّ «افتحه»
// ثم يردّه الخادم أسوأ من شاشةٍ لا تعرضه.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/availability.dart';

Session _session() => Session()
  ..userId = 'p1'
  ..email = 'p@sdd.company'
  ..appUserId = 'demo-provider'
  ..providerId = 'demo-provider'
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
  home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, {double height = 3200}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// اليومُ المزروع، ثمّ **الانتقالُ إلى شهره إن لزم**.
///
/// **وهذا وُلد من سقوطٍ متكرّر:** الاختبارُ كان يزرع «اليوم + ٣» ويقرأ الشبكة
/// وهي تعرض **الشهر الحاليّ وحده**. فإن وقع اليومُ الثالثُ في الشهر التالي —
/// وذلك يقع في آخر ثلاثة أيّامٍ من كلّ شهر — لم يُوجد شيء، وسقط الاختبارُ
/// على شيفرةٍ سليمة.
///
/// والشاشةُ فيها انتقالٌ بين الشهور أصلاً، فيُستعمل. وبه يصير الاختبارُ
/// مستقلّاً عن يوم تشغيله، **ويقيس زرَّ الشهر التالي في الطريق**.
DateTime _seedDay() => DateTime.now().add(const Duration(days: 3));

Future<void> _revealSeeded(WidgetTester tester) async {
  final now = DateTime.now();
  final target = _seedDay();
  final months =
      (target.year - now.year) * 12 + (target.month - now.month);
  for (var i = 0; i < months; i++) {
    await tester.tap(find.byTooltip('الشهر التالي'));
    await _settle(tester);
  }
}

void main() {
  setUp(demoResetDays);

  testWidgets('اليومان يُعرضان بسببيهما', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(AvailabilityScreen(session: _session())));
    await _settle(tester);

    // بيانات العرض فيها يومٌ بحجزٍ ويومٌ بعذر — وكلاهما في هذا الشهر أو الذي
    // يليه، فقد لا يظهران معاً. والمعروض منهما يقول سببه.
    final visible = find.textContaining('صيانة').evaluate().isNotEmpty ||
        find.textContaining('محجوز').evaluate().isNotEmpty;
    expect(visible, isTrue);
  });

  testWidgets('**وآخرُ يومٍ في الشهر يُعرض — ولو حمل ساعة**', (tester) async {
    // **حارسٌ لا يتبع تاريخَ اليوم.** يضع العلامةَ في آخر يومٍ من الشهر
    // المعروض صراحةً، فيسأل السؤالَ نفسه في كلّ يومٍ من السنة.
    //
    // وما يحرسه خطأٌ وقع فعلاً: الشاشةُ تطلب المدى إلى
    // `DateTime(سنة, شهر + 1, 0)` — آخرُ يومٍ عند **منتصف ليله** — وعلامةٌ
    // في ذلك اليوم ومعها ساعةٌ تكون «بعده» بالمقارنة اللحظيّة فتسقط. فكان
    // آخرُ يومٍ في كلّ شهرٍ يختفي من التقويم، ولم يظهر ذلك في اختبارٍ واحدٍ
    // تسعةً وعشرين يوماً من كل ثلاثين — حتى سقط اختباران في الثامن
    // والعشرين من أغسطس، لأنّ «اليوم + ٣» صار الحادي والثلاثين.
    _phone(tester);
    final now = DateTime.now();
    final lastOfMonth = DateTime(now.year, now.month + 1, 0);
    demoDays = [
      DayMark(
        // ساعةٌ ودقيقة، كما تأتي من `DateTime.now()` دائماً.
        day: lastOfMonth.add(const Duration(hours: 13, minutes: 27)),
        blocked: true,
        note: 'آخرُ الشهر',
      ),
    ];

    await tester.pumpWidget(_wrap(AvailabilityScreen(session: _session())));
    await _settle(tester);

    expect(find.textContaining('آخرُ الشهر'), findsOneWidget,
        reason: 'سقط آخرُ يومٍ في الشهر من التقويم');
  });

  testWidgets('ويومُ الحجز بلا زرّ «افتحه»', (tester) async {
    // **وهذا ما ينكسر بصمت:** زرٌّ يَعِد بفتح يومٍ لا يُفتح — يضغطه صاحبه فيظنّ
    // أنه فُتح، أو يردّه الخادم برسالةٍ لا يفهمها.
    _phone(tester);
    demoDays = [
      DayMark(
        day: _seedDay(),
        blocked: true,
        note: 'محجوز — BK-1',
      ),
    ];
    await tester.pumpWidget(_wrap(AvailabilityScreen(session: _session())));
    await _settle(tester);
    await _revealSeeded(tester);

    expect(find.textContaining('محجوز — BK-1'), findsOneWidget);
    expect(find.text('افتحه'), findsNothing);
    expect(find.text('حجز'), findsOneWidget);
  });

  testWidgets('ويومُ العذر له زرّ يفتحه فعلاً', (tester) async {
    _phone(tester);
    demoDays = [DayMark(day: _seedDay(), blocked: true, note: 'سفر')];

    await tester.pumpWidget(_wrap(AvailabilityScreen(session: _session())));
    await _settle(tester);
    await _revealSeeded(tester);

    expect(find.text('افتحه'), findsOneWidget);
    await tester.tap(find.text('افتحه'));
    await _settle(tester);

    // لا يكفي أن يختفي الزرّ: الحالة نفسها في «القاعدة» يجب أن تتغيّر.
    expect(demoDays, isEmpty);
    expect(find.text('شهرٌ مفتوحٌ كلُّه'), findsOneWidget);
  });

  testWidgets('والعنوان يذكر الشهر المعروض', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(AvailabilityScreen(session: _session())));
    await _settle(tester);

    final now = DateTime.now();
    expect(find.text(formatMonth(DateTime(now.year, now.month))), findsOneWidget);
  });

  testWidgets('ولكلِّ حالةٍ لونُها: متاحٌ أخضر ومحجوزٌ أزرق', (tester) async {
    // **واللون هنا معنىً لا زينة:** صاحبُ القاعة يمرّ على الشهر بعينه لا
    // بالقراءة — أخضرُ يقبل حجزاً، وأزرقُ محجوزٌ لا يُفتح إلا بإلغاء، وأحمرُ
    // أغلقه هو ويفتحه متى شاء. ولونان متقاربان يجعلانه يعتذر عن حجزٍ ظنّه
    // مشغولاً.
    // يومان **في الشهر المعروض نفسه** لا «بعد ثلاثة أيام»: الشاشة تفتح على
    // شهر اليوم، وإضافةُ ثلاثةٍ إلى يومٍ في آخر الشهر تُخرجهما من الشبكة —
    // فيسقط الاختبار في أواخر كل شهرٍ ويمرّ في أوّله. وهذا أسوأ من ساقطٍ
    // دائماً: يُنسب إلى الحظّ.
    //
    // واليومان الماضيان يصلحان هنا: الصبغة لا تتغيّر بمضيّ اليوم — يبهت
    // الرقم وحده.
    final now = DateTime.now();
    demoDays = [
      DayMark(day: DateTime(now.year, now.month, 2), blocked: true, note: 'محجوز — BK-9'),
      DayMark(day: DateTime(now.year, now.month, 3), blocked: true, note: 'سفر'),
    ];

    await tester.pumpWidget(_wrap(AvailabilityScreen(session: _session())));
    await _settle(tester);

    // **الخلايا لا نقاطُ المفتاح.** أوّلُ صياغةٍ لهذا التأكيد قرأت كلَّ
    // `Container` في الشاشة، فمرّت وأنا أوحّد لوني «متاح» و«محجوز» عمداً:
    // نقطةُ المفتاح كانت ما زالت زرقاء فأرضته. فيُقرأ الآن ما يُرسم في
    // المربّعات نفسها — والصبغة تميّزها: النقاط مصمتة والخلايا مخفّفة.
    final fills = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .whereType<Color>()
        .where((c) => c.a > 0 && c.a < 1)
        .toList();

    bool tinted(Color tone, double alpha) => fills.any((c) =>
        c.r == tone.r &&
        c.g == tone.g &&
        c.b == tone.b &&
        (c.a - alpha).abs() < 0.001);

    expect(tinted(AppColors.good, Tint.chip), isTrue, reason: 'لا يومَ متاحاً أخضر');
    expect(tinted(AppColors.booked, Tint.disc), isTrue, reason: 'لا يومَ محجوزاً أزرق');
    expect(tinted(AppColors.critical, Tint.chip), isTrue, reason: 'لا يومَ مغلقاً أحمر');
  });

  test('وألوانُ التقويم الثلاثة مقروءةٌ على صبغاتها', () {
    // القياسُ لا الذوق: صبغةٌ ترتفع غداً فيصير رقمُ اليوم لا يُقرأ في الشمس،
    // ولا يظهر ذلك في أي سجلّ.
    double lin(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
    double lum(Color c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    const card = Color(0xFFFFFFFE);
    Color over(Color fg, double a) => Color.from(
      alpha: 1,
      red: fg.r * a + card.r * (1 - a),
      green: fg.g * a + card.g * (1 - a),
      blue: fg.b * a + card.b * (1 - a),
    );
    double ratio(Color a, Color b) {
      final x = lum(a), y = lum(b);
      return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
    }

    for (final (name, tone, alpha) in [
      ('متاح', AppColors.good, Tint.chip),
      ('محجوز', AppColors.booked, Tint.disc),
      ('أغلقتَه', AppColors.critical, Tint.chip),
    ]) {
      final r = ratio(tone, over(tone, alpha));
      expect(r, greaterThanOrEqualTo(4.5), reason: '«$name» يعطي ${r.toStringAsFixed(2)}:1');
    }
  });
}
