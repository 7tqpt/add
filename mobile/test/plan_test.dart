// منظِّم حفل الزفاف: عدٌّ تنازلي، وتقدّمٌ محسوب، وقائمةٌ تُشطب.
//
// **وأخطر ما يُقاس هنا نسبةُ التقدّم.** رقمٌ يُعرض في أعلى الشاشة ويُصدَّق:
// من رآه ٨٠٪ قبل أسبوعٍ من العرس اطمأنّ. فإن كان محسوباً من عددٍ خاطئ —
// أو مكتوباً لا محسوباً — طَمْأنَ في غير موضعه.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/labels.dart';
import 'package:aras/src/screens/plan.dart';
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
    // حدُّ رسمٍ حول الشاشة — تُصوَّر منه البكسلات حين لا يكفي سؤالُ الشجرة.
    child: RepaintBoundary(
      key: const ValueKey('plan-paint'),
      child: Scaffold(body: child),
    ),
  ),
);

/// الضغطُ بعد الإحضار إلى الشاشة.
///
/// **ولولاها لمرّت الاختبارات كاذبة:** الشاشة أطولُ من نافذة الاختبار
/// (‏٨٠٠×٦٠٠‏)، فما تحت الطيّ مبنيٌّ لكنه خارج المشهد — و`tap` عليه يُطلق
/// ضغطةً في مكانٍ لا شيء فيه، فلا يقع شيءٌ ولا يُرفع خطأ.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// قائمةُ عرضٍ معروفةُ العدد: ثلاثٌ من ثمانٍ منجَزة = ‎٣٨٪‎.
void _resetTasks() {
  demoPlanTasks = [
    const PlanTask(id: 'a', title: 'حجز القاعة', done: true, dueDate: '', sortOrder: 10),
    const PlanTask(id: 'b', title: 'المهر', done: true, dueDate: '', sortOrder: 20),
    const PlanTask(id: 'c', title: 'عقد القران', done: true, dueDate: '', sortOrder: 30),
    const PlanTask(id: 'd', title: 'حجز المصوّر', done: false, dueDate: '', sortOrder: 40),
    const PlanTask(id: 'e', title: 'فستان العروس', done: false, dueDate: '', sortOrder: 50),
    const PlanTask(id: 'f', title: 'بطاقات الدعوة', done: false, dueDate: '', sortOrder: 60),
    const PlanTask(id: 'g', title: 'سيارة الزفّة', done: false, dueDate: '', sortOrder: 70),
    const PlanTask(id: 'h', title: 'الحلويات', done: false, dueDate: '', sortOrder: 80),
  ];
}

/// المسارات التي طُلب لها رابطٌ — **وهذا ما يُقاس، لا ما رُسم على الزجاج**.
///
/// لا شبكةَ في الاختبار، فلا صورةَ تُحمَّل. والسؤالُ ليس «أظهرت صورة؟» بل
/// «أيَّ مسارٍ طلبت الشاشةُ؟» — وهو الذي يفرّق غلافَ الحجز الأقدم من غيره.
///
/// **ويُردّ رابطٌ لا `null`**: `Api.mediaUrl` تردّ `null` حين لا تُضبط
/// أسرارُ القاعدة، فلا تُبنى `Image` أصلاً — واختبارٌ يقبل ذلك يقيس شاشةً
/// غيرَ التي على الجهاز. وقد اختفت بطاقاتُ الحجز على جهازٍ حقيقيٍّ والحزمةُ
/// خضراء، لهذا السبب بعينه.
List<String> requestedPaths() {
  final seen = <String>[];
  Api.mediaUrlOverride = (path) {
    seen.add(path);
    return 'https://example.invalid/$path';
  };
  return seen;
}

/// نصُّ العدّ التنازلي كما يُقرأ — و**قِطَعُه**.
///
/// صار الرقمُ جزءاً من الجملة (`Text.rich`) لا سطراً فوقها، فلا يجده
/// `find.text`. ويُقرأ من شجرة العناصر: الجملةُ كلُّها، وحجمُ ما كان رقماً.
({String all, double? digitSize, TextStyle? digitStyle}) countdownOf(
    WidgetTester tester) {
  final widget = tester.widget<Text>(find.byKey(const ValueKey('countdown')));
  final root = widget.textSpan! as TextSpan;
  final buffer = StringBuffer();
  TextStyle? digitStyle;
  for (final part in root.children!.cast<TextSpan>()) {
    buffer.write(part.text);
    if (RegExp(r'^\d+$').hasMatch(part.text ?? '')) digitStyle = part.style;
  }
  return (
    all: buffer.toString(),
    digitSize: digitStyle?.fontSize,
    digitStyle: digitStyle,
  );
}


final List<Booking> _bookings = List.of(demoBookings);
final List<WeddingPlan> _plans = List.of(demoPlans);

void main() {
  setUp(() {
    _resetTasks();
    demoBookings = List.of(_bookings);
    demoPlans = List.of(_plans);
    requestedPaths();
  });
  tearDown(() => Api.mediaUrlOverride = null);

  testWidgets('وغلافُ الرأس من أقدم حجزٍ في الخطّة', (tester) async {
    final seen = requestedPaths();
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // `b1` أقدمُ من `b2` بمئةٍ واثنتين وخمسين ساعة، وخدمتُه `s1`.
    // **ويُقاس أنّه وحدَه**: لكلتا الخدمتين غلافٌ، فطلبُ الآخر خطأٌ لا نقص.
    expect(seen, ['p1/s1/hall.jpg'],
        reason: 'الغلافُ ليس غلافَ الحجز الأقدم');
  });

  testWidgets('وحجزٌ ملغىً لا يُعطي الخطّةَ غلافَها', (tester) async {
    // **أقدمُ من الاثنين** — فلو عُدّ لأخذ الرأسَ.
    demoBookings = [
      Booking(
        id: 'b-old-cancelled',
        planId: 'pl1',
        reference: 'BK-2026-000001',
        createdAt: DateTime.now()
            .subtract(const Duration(hours: 900))
            .toIso8601String(),
        userName: 'أحمد الشرعبي',
        providerName: 'مطبخ الأصالة',
        serviceTitle: 'مندي وحنيذ لـ300 شخص',
        eventDate: demoBookings.first.eventDate,
        eventTime: '19:00',
        address: 'حي السنينة — صنعاء',
        guestsCount: 300,
        status: BookingStatus.cancelled,
        totalPrice: 420000,
        depositAmount: 126000,
        paidAmount: 0,
      ),
      ...demoBookings,
    ];

    final seen = requestedPaths();
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(seen, ['p1/s1/hall.jpg'],
        reason: 'غلافُ حجزٍ ملغىً صار رأسَ الخطّة');
  });

  testWidgets('وخطّةٌ بلا حجوزاتٍ لا تطلب غلافاً ولا تسقط', (tester) async {
    demoBookings = [];
    final seen = requestedPaths();

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(seen, isEmpty, reason: 'طُلب غلافٌ ولا حجزَ في الخطّة');
    // والرأسُ قائمٌ كما هو.
    expect(countdownOf(tester).all, 'بقي 28 يوماً');
  });

  testWidgets('العدُّ التنازلي رقمٌ كبيرٌ لا سطرٌ في زحام', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // خطّةُ العرض بعد ٢٨ يوماً.
    final line = countdownOf(tester);
    expect(line.all, 'بقي 28 يوماً');

    // **الحجم جزءٌ من المعنى:** رقمٌ بحجم الكلمة المجاورة ليس عدّاً تنازليّاً.
    expect(line.digitSize, isNotNull, reason: 'الرقمُ لم يُفرَد بحجمٍ خاصّ');
    expect(line.digitSize, greaterThanOrEqualTo(22));

    // **وللرقم خطٌّ يرسمه.**
    //
    // قِطعةٌ تُعلن `fontFamilyFallback` بلا `fontFamily` تُلغي عائلةَ الخطّ
    // الموروثةَ من الثيمة وتضع محلَّها قائمةَ الاحتياطيّ وحدَها — فيخرج
    // الرقمُ **مربّعاً مصمتاً**. وقد خرج كذلك في لقطةٍ حقيقيّة، ولم يسقط
    // له اختبار: النصُّ والحجمُ كلاهما سليمٌ في الشجرة.
    expect(line.digitStyle?.fontFamilyFallback, isNull,
        reason: 'أسلوبُ الرقم يُعلن احتياطيّاً بلا عائلة — تُرسم أرقامُه مربّعات');
  });

  testWidgets('وصيغةُ العدد عربيّةٌ لا «2 يوماً»', (tester) async {
    // **وهذا ما يسقط بالتركيب اليدويّ.** العربيّةُ مثنّىً وجمعُ قلّةٍ
    // وتمييز، و`countdownLabel` تعرفها. ومن كتب `'بقي $days يوماً'` أخرج
    // «بقي 2 يوماً» — وهي عجمة.
    final soon = DateTime.now().add(const Duration(days: 2));
    final p = demoPlans.first;
    demoPlans = [
      WeddingPlan(
        id: p.id,
        title: p.title,
        weddingDate: soon.toIso8601String().substring(0, 10),
        governorate: p.governorate,
        guestsCount: p.guestsCount,
        budget: p.budget,
        status: p.status,
        servicesCount: p.servicesCount,
        totalCost: p.totalCost,
        paidAmount: p.paidAmount,
        remainingAmount: p.remainingAmount,
      ),
    ];

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(countdownOf(tester).all, 'بقي يومين');
  });

  testWidgets('والتقدّم محسوبٌ من المشطوب لا مكتوب', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('38٪'), findsOneWidget);
    expect(find.text('3 من 8 مهامّ مكتملة'), findsOneWidget);

    // **والشريطُ يتبع الرقمَ لا يُرسم بقيمةٍ ثابتة**: رقمٌ يقول ‎٣٨‎ وشريطٌ
    // يملأ ستّين يقرؤهما صاحبُهما رقمين.
    // **وبالمفتاح لا بالنوع**: أشرطةُ الأقسام في «تفاصيل المصروفات» من
    // النوع نفسِه، فبحثٌ بالنوع يقع على أوّلِ ما يجد.
    final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('plan-bar')));
    expect(bar.value, closeTo(0.38, 0.001));

    // **والحلقةُ كذلك**: رقمٌ مكتوبٌ في جوفِ حلقةٍ ممتلئةٍ بغيره أسوأُ من
    // رقمٍ وحدَه — العينُ تصدّق القوسَ قبل أن تقرأ.
    final ring = tester.widget<PercentRing>(
        find.byKey(const ValueKey('plan-percent')));
    expect(ring.value, closeTo(0.38, 0.001));

    // وسطرُ التشجيع يتبع الحال.
    expect(find.text('أنت على الطريق الصحيح'), findsOneWidget);
  });

  testWidgets('وسطرُ التشجيع يتبدّل بالحال لا يثبت', (tester) async {
    // لا مهامَّ أصلاً.
    demoPlanTasks = [];
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);
    expect(find.text('لم تُفتح قائمة التجهيز بعد'), findsOneWidget);
    expect(find.text('أنت على الطريق الصحيح'), findsNothing);

  });

  group('وحبرُ الصدر يُقرأ على تدرّجه', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    Color on(Color ink, Color ground) => Color.alphaBlend(ink, ground);

    // **ويُقاس على طرفَي التدرّج لا على وسطه.** وهذا درسٌ قديمٌ في هذه
    // الشجرة: قِيس ذهبُ النبيذيّ على `accent` وحدَه فأعطى ‎٥٫٤٥:١‎، وكان
    // على الطرف الفاتح ‎٤٫٠٩:١‎ — تحت العتبة منذ كُتب.
    for (final ground in [AppColors.brandLift, AppColors.brand]) {
      test('ذهبُ العدّ التنازليّ على ${ground.toARGB32().toRadixString(16)}',
          () {
        final r = ratio(AppColors.goldOnBrand, ground);
        expect(r, greaterThanOrEqualTo(4.5),
            reason: 'العدُّ التنازليُّ ${r.toStringAsFixed(2)}:1');
      });

      test('وحبرُ الموعد على ${ground.toARGB32().toRadixString(16)}', () {
        final r = ratio(on(Colors.white.withValues(alpha: 0.88), ground), ground);
        expect(r, greaterThanOrEqualTo(4.5),
            reason: 'التاريخُ والمحافظةُ ${r.toStringAsFixed(2)}:1');
      });
    }

    test('**والذهبُ العاديُّ لا يصلح هناك** — وهو سببُ اللون الجديد', () {
      // لو عاد أحدٌ فوضع `AppColors.gold` في الصدر، هذا الرقمُ يقول لماذا.
      final r = ratio(AppColors.gold, AppColors.brandLift);
      expect(r, lessThan(4.5),
          reason: 'الذهبُ العاديُّ على الطَّفليّ ${r.toStringAsFixed(2)}:1');
    });
  });

  testWidgets('**ومن لم يحجز لا يرى مربّعاً فارغاً**', (tester) async {
    // **وهذه هي علّةُ الشكل القديم كلِّها**: الغلافُ لوحٌ يجاور النصّ،
    // فمن لم يحجز خدمةً لها صورةٌ — وهي حالُ كلِّ من فتح خطّته أوّلَ مرّة —
    // يرى مربّعاً فارغاً فيه أيقونةُ صورةٍ مكسورة. واختار صاحبُ المنصّة أن
    // تذوب الصورةُ في الخلفيّة إن وُجدت، ولا يُرسم شيءٌ إن لم توجد.
    demoBookings = [];
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.byType(BigNumberIn), findsOneWidget, reason: 'لا صدرَ أصلاً');
    expect(find.byType(MediaThumb), findsNothing,
        reason: 'موضعُ صورةٍ مرسومٌ لمن لا صورةَ له');

    // **ولا يكفي ألّا تُبنى صورة**: لوحٌ بلونٍ فاتحٍ محلَّها يخرج مربّعاً
    // باهتاً في الصدر الطَّفليّ — والشجرةُ لا تُنكره. فتُقرأ البكسلات.
    final countdown = tester.getRect(find.byType(BigNumberIn));
    late ByteData pixels;
    late int width;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('plan-paint')));
      final image = await boundary.toImage();
      width = image.width;
      pixels = (await image.toByteData())!;
      image.dispose();
    });

    // **ونقطةُ القياس تُحسب من عنصرٍ في الصدر لا تُكتب رقماً**: حشوةُ
    // القائمة وعرضُ الشاشة يتبدّلان، ورقمٌ مكتوبٌ يقع على أرضيّة الصفحة
    // فيُقرأ بياضُها عطباً — وقد وقع.
    final chip = tester.getRect(find.text(planStatusLabel(demoPlans.first.status)));
    final logicalWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final scale = width / logicalWidth;
    final x = ((chip.left - 6) * scale).round();
    final y = (countdown.center.dy * scale).round();
    int at(int c) => pixels.getUint8(((y * width) + x) * 4 + c);
    final luma = (0.2126 * at(0) + 0.7152 * at(1) + 0.0722 * at(2)) / 255;
    expect(luma, lessThan(0.4),
        reason: 'طرفُ الصدر فاتحٌ — لوحُ صورةٍ فارغٌ لا تدرّج (لمعان '
            '${luma.toStringAsFixed(2)})');
  });

  testWidgets('**وعدُّ الأيّام بذهبٍ يُقرأ على الصدر**', (tester) async {
    // **ولا يُسأل اللونُ في اللوحة، بل ما رُسم**: `BigNumberIn` كانت تكتب
    // لونَها بيدها، فمن نسي أن يمرّر لوناً خرج العدُّ داكناً لا يُرى —
    // وقد خرج كذلك في أوّل رسمةٍ للوح.
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    final big = tester.widget<BigNumberIn>(find.byType(BigNumberIn));
    expect(big.color, AppColors.goldOnBrand,
        reason: 'العدُّ التنازليُّ بذهب الفاتح على أرضيّةٍ طَفليّة');
  });

  testWidgets('**والمحافظةُ بأيقونتها لا ملصوقةً بالتاريخ**', (tester) async {
    // **وكانا في سطرٍ واحدٍ تحت أيقونة تقويم** — «٢٤ أكتوبر ٢٠٢٦ · أمانة
    // العاصمة» — فيُقرأ اسمُ المحافظة جزءاً من التاريخ. وفي تصميم صاحب
    // المنصّة لكلٍّ أيقونتُه وبينهما خيط.
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    final plan = demoPlans.first;
    expect(plan.governorate, isNotEmpty, reason: 'خطّةُ العرض بلا محافظة');

    // نصّان اثنان لا نصٌّ واحدٌ فيه الاثنان.
    expect(find.text(formatDate(plan.weddingDate)), findsOneWidget);
    expect(find.text(plan.governorate), findsOneWidget,
        reason: 'المحافظةُ ليست نصّاً قائماً بنفسه');
    expect(find.byIcon(Icons.place_outlined), findsWidgets,
        reason: 'لا أيقونةَ موقعٍ للمحافظة');

    // **ولا يُسأل النصُّ عمّا فيه، بل يُقاس ما رُسم**: جُمعا في قرصٍ واحدٍ
    // أوّلَ مرّةٍ كما في تصميمه، فخرج الاثنان مقصوصين — «24 أكتوبر …» و
    // «أمانة العا…» — والنصُّ في الشجرة كاملٌ لا يكشف ذلك.
    for (final text in [formatDate(plan.weddingDate), plan.governorate]) {
      final para = tester.renderObject<RenderParagraph>(find.text(text));
      expect(para.didExceedMaxLines, isFalse, reason: 'قُصّ: $text');
    }
  });

  testWidgets('**ومن أتمّ المهامَّ كلَّها يُختم له لا يُترك بفراغ**',
      (tester) async {
    // **وقائمةٌ تخلو فجأةً تُقرأ عطباً لا إنجازاً** — «أين مهامّي؟». فموضعُ
    // المهامّ الذاهبةِ يُملأ بخَتمٍ: قرصٌ وعلامةُ صحٍّ وشرارات، على تصميمٍ
    // أرسله صاحبُ المنصّة.
    demoPlanTasks = [
      for (final t in demoPlanTasks)
        PlanTask(
          id: t.id,
          title: t.title,
          done: true,
          dueDate: t.dueDate,
          sortOrder: t.sortOrder,
        ),
    ];

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('أنهيت كلَّ شيء — مبارك!'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsWidgets,
        reason: 'لا خَتمَ في موضع المهامّ الذاهبة');

    // **ويبقى بابُ الإضافة**: من أتمّ اليومَ يضيف غداً.
    expect(find.text('أضف مهمّة…'), findsOneWidget);
  });

  testWidgets('ومن لم يشطب شيئاً يُدعى إلى الأولى لا يُهنَّأ', (tester) async {
    demoPlanTasks = [
      for (final t in demoPlanTasks)
        PlanTask(
          id: t.id,
          title: t.title,
          done: false,
          dueDate: t.dueDate,
          sortOrder: t.sortOrder,
        ),
    ];

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('ابدأ بأوّل مهمّة'), findsOneWidget);
    expect(find.text('أنت على الطريق الصحيح'), findsNothing);
  });

  testWidgets('والشطبُ يحرّك النسبة في الحال', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);
    expect(find.text('38٪'), findsOneWidget);

    // أوّلُ مربّعٍ في القائمة لأوّل مهمّةٍ **غير** منجزة — فالمنجَز مطويّ.
    await _tap(tester, find.byType(Checkbox).first);

    // أربعٌ من ثمانٍ.
    expect(find.text('50٪'), findsOneWidget);
    expect(demoPlanTasks.where((t) => t.done).length, 4);
  });

  testWidgets('والمنجَزُ مطويٌّ حتى يُطلب — لئلّا يدفن ما بقي', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('حجز القاعة'), findsNothing);
    expect(find.text('حجز المصوّر'), findsOneWidget);

    await _tap(tester, find.text('المنجَز (3)'));
    expect(find.text('حجز القاعة'), findsOneWidget);
  });

  testWidgets('ومهمّةٌ تُضاف من الشاشة نفسها', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'استئجار كراسي');
    await _tap(tester, find.byIcon(Icons.add).last);

    expect(find.text('استئجار كراسي'), findsOneWidget);
    expect(demoPlanTasks.length, 9);
  });

  testWidgets('والمربّعاتُ الأربعة تعرض أرقام الخطّة', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('المهامّ'), findsOneWidget);
    expect(find.text('5 متبقّية'), findsOneWidget);
    expect(find.text('قائمة الضيوف'), findsOneWidget);
    expect(find.text('400 ضيفاً'), findsOneWidget);
  });

  testWidgets('وقاعدةٌ بلا مهامّ تنقص ميزةً ولا تُسقط شاشة', (tester) async {
    // من لم يشغّل `plan_tasks.sql` بعد.
    demoPlanTasks = [];

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // العدُّ والميزانية يعملان كما كانا.
    expect(countdownOf(tester).all, 'بقي 28 يوماً');
    expect(find.text('الميزانية'), findsWidgets);
    expect(find.textContaining('لم تُفتح قائمة التجهيز'), findsWidgets);
    expect(find.text('0٪'), findsOneWidget);
  });

  testWidgets('ويبقى الرأسُ مرسوماً بخطّ الجهاز الكبير وللصورة رابط',
      (tester) async {
    // **وهذه صنوُ ما سقط في «حجوزاتي»**: ارتفاعٌ مأخوذٌ من النصّ يسأل
    // الصورةَ عن ارتفاعها الطبيعيّ فتُجيب بلا نهاية.
    tester.view.physicalSize = const Size(360, 1400);
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
          child: Scaffold(body: PlanScreen(session: _session())),
        ),
      ),
    ));
    await _settle(tester);

    expect(find.text('قائمة التجهيز'), findsOneWidget, reason: 'اختفت الشاشة');
    expect(tester.takeException(), isNull, reason: 'انهار تخطيطُ الرأس');
  });
}
