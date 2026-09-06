// الشريطُ العلويّ.
//
// كان بطاقةً عائمةً بظلٍّ وزوايا، تحت كلّ أيقونةٍ فيها قرصٌ أبيض، وسطحُها هو
// هو سواءٌ كان تحته فراغٌ أو محتوى. فصار ممتدّاً من حافّةٍ إلى حافّة، بلا
// سطحٍ ما دامت الشاشةُ في أعلاها، ثمّ زجاجٌ وشعرةٌ حين يمرّ المحتوى تحته.
//
// **وأكثرُ ما يُقاس هنا مواضعُ مرسومةٌ لا حقولُ ودجات.** «الجرسُ يميناً»
// و«العنوانُ في الوسط» لا يُقاسان بترتيب الأبناء في الشيفرة: في العربية أوّلُ
// أبناء الصفّ أقصى اليمين، والوسطُ الذي يعطيه `Expanded` وسطُ ما بقي من
// العرض لا وسطُ الشريط. فيُسأل الرسمُ عن الإحداثيّات.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
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

void _phone(WidgetTester tester, {double height = 2340}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _openShell(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(_wrap(CustomerShell(session: Session())));
  await _settle(tester);
}

/// أرضيّةُ الشريط كما تُرسم فعلاً — لا كما مُرِّرت إليه.
///
/// `AnimatedContainer` يحمل الهدفَ في حقله، وما يُرسم قيمةٌ بينيّة. فيُقرأ
/// `DecoratedBox` الذي يبنيه، وهو الذي يُلوّن.
BoxDecoration _surface(WidgetTester tester) => tester
    .widget<DecoratedBox>(find
        .descendant(
            of: find.byType(GlassHeader), matching: find.byType(DecoratedBox))
        .first)
    .decoration as BoxDecoration;

double _alpha(WidgetTester tester) => _surface(tester).color?.a ?? 0;

/// شدّةُ التمويه كما رُسمت.
///
/// و`ImageFilter` لا يُفصح عن معاملاته إلّا في وصفه — فيُقرأ منه.
double _blur(WidgetTester tester) {
  final filter = tester
      .widget<BackdropFilter>(find.descendant(
          of: find.byType(GlassHeader), matching: find.byType(BackdropFilter)))
      .filter
      .toString();
  // ‏`ImageFilter.blur(20.0, 20.0, clamp)`‎ — بلا أسماءٍ للمعاملات.
  final match = RegExp(r'blur\(([\d.]+)').firstMatch(filter);
  expect(match, isNotNull, reason: 'تعذّر قراءةُ شدّة التمويه من «$filter»');
  return double.parse(match!.group(1)!);
}

/// لونُ العنوان كما رُسم.
Color _titleColour(WidgetTester tester) => tester
    .widget<Text>(find
        .descendant(of: find.byType(GlassHeader), matching: find.byType(Text))
        .first)
    .style!
    .color!;

/// لونُ رموز الشريط كما رُسمت.
Color _iconColour(WidgetTester tester) => tester
    .widget<IconButton>(find
        .descendant(
            of: find.byType(GlassHeader), matching: find.byType(IconButton))
        .first)
    .style!
    .foregroundColor!
    .resolve(const <WidgetState>{})!;

/// تمريرُ الشاشة رأسيّاً.
Future<void> _scroll(WidgetTester tester, double by) async {
  await tester.drag(find.byType(ListView).first, Offset(0, -by));
  await _settle(tester);
}

// ── نسبةُ التباين ───────────────────────────────────────────────────────────
// تُحسب هنا ولا تُنقل من تعليق: أرقامُ التباين في التعليقات تعتّق حين يتبدّل
// لونٌ واحد، ولا يظهر عتقُها إلّا لعينٍ تقرأ في الشمس.
double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// لونُ `top` بشفافيّته فوق `under` — ما تراه العينُ من الطبقتين.
Color _over(Color top, Color under) => Color.from(
      alpha: 1,
      red: top.r * top.a + under.r * (1 - top.a),
      green: top.g * top.a + under.g * (1 - top.a),
      blue: top.b * top.a + under.b * (1 - top.a),
    );

void main() {
  group('ترتيبُ الشريط', () {
    testWidgets('**الجرسُ يمينَه والرسائلُ يسارَه**', (tester) async {
      // **ولا يُقاس بترتيب الأبناء في الشيفرة.** في العربية أوّلُ أبناء
      // الصفّ أقصى اليمين — وهو ما جعلني أكتب سهمَي «يمين» و«يسار»
      // مقلوبَين في ورقةِ عرضٍ سابقة. فيُسأل الرسمُ.
      await _openShell(tester);
      final bell = tester.getCenter(find.byType(BellIconButton)).dx;
      final chat = tester.getCenter(find.byType(ChatIconButton)).dx;
      expect(bell, greaterThan(chat),
          reason: 'الجرسُ ليس في يمين الشريط');
    });

    testWidgets('**والعنوانُ في وسط الشريط لا في وسط ما بقي منه**',
        (tester) async {
      // **وهذا هو الفرق الذي يُنسى.** `Expanded` في صفٍّ يعطي العنوانَ وسطَ
      // المساحة الباقية بعد الأيقونات، فيميل عن وسط الشاشة بقدر فرق
      // الطرفين. والمطلوبُ وسطُ الشريط نفسِه.
      await _openShell(tester);
      final bar = tester.getRect(find.byType(GlassHeader));
      final title = tester.getRect(find.descendant(
          of: find.byType(GlassHeader), matching: find.text('الرئيسية')));
      expect((title.center.dx - bar.center.dx).abs(), lessThan(1.0),
          reason: 'العنوانُ مائلٌ عن وسط الشريط');
    });

    testWidgets('ولا يزحف تحت الأيقونات مهما طال', (tester) async {
      // «خطة العرس» و«حجوزاتي» قصيران، لكنّ العنوانَ يُملأ من قائمةٍ تُزاد.
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: GlassHeader(
          title: 'عنوانٌ طويلٌ جدّاً لا ينتهي أبداً ويزحف على ما حوله',
          start: BellIconButton(unread: 0, onTap: () {}),
          end: ChatIconButton(unread: 0, onTap: () {}),
        ),
      )));
      await tester.pump();

      final title = tester.getRect(find.text(
          'عنوانٌ طويلٌ جدّاً لا ينتهي أبداً ويزحف على ما حوله'));
      final bell = tester.getRect(find.byType(BellIconButton));
      final chat = tester.getRect(find.byType(ChatIconButton));
      expect(title.right, lessThanOrEqualTo(bell.left + 0.5),
          reason: 'العنوانُ يزحف تحت الجرس');
      expect(title.left, greaterThanOrEqualTo(chat.right - 0.5),
          reason: 'العنوانُ يزحف تحت أيقونة الرسائل');
    });
  });

  group('السطحُ يتبع التمرير', () {
    testWidgets('**فلا سطحَ ولا شعرةَ ما دامت الشاشةُ في أعلاها**',
        (tester) async {
      await _openShell(tester);
      expect(_alpha(tester), 0,
          reason: 'سطحٌ أبيضُ فوق شاشةٍ لم تُمرَّر');
      expect(_surface(tester).border?.bottom.color, Colors.transparent,
          reason: 'شعرةٌ تفصل الرأسَ عن فراغ');
    });

    testWidgets('**ويظهران حين يمرّ المحتوى تحته**', (tester) async {
      await _openShell(tester);
      await _scroll(tester, 260);
      expect(_alpha(tester), greaterThan(0.5),
          reason: 'المحتوى يمرّ تحت رأسٍ بلا سطح — فيُقرأ العنوانُ على صورة');
      expect(_surface(tester).border?.bottom.color, AppColors.hairline);
    });

    testWidgets('**والتمريرُ الأفقيُّ لا يُظهرهما**', (tester) async {
      // في الرئيسية بطاقتان كبيرتان تُمرَّران بالإبهام، وصفُّ عروضٍ أفقيّ —
      // وكلاهما يبثّ إشعاراتِ تمريرٍ كالرأسيّ تماماً. فمن مرّر بطاقةً وهو في
      // أعلى الشاشة كان يرى الزجاجَ يظهر بلا سبب.
      await _openShell(tester);
      await tester.drag(find.byType(PageView), const Offset(260, 0));
      await _settle(tester);
      expect(_alpha(tester), 0, reason: 'تمريرةٌ أفقيّةٌ أظهرت الزجاج');
    });

    testWidgets('**وتبديلُ التبويب يعيده إلى حاله**', (tester) async {
      // **ولا شيءَ يعيده غيرُ هذا.** الشاشةُ الجديدة تُبنى عند الصفر ولا تبثّ
      // إشعارَ تمريرٍ أصلاً، فيبقى الزجاجُ والشعرةُ معلَّقين فوق شاشةٍ لم
      // تُمرَّر حتى يمرّرها صاحبُها ويعود.
      await _openShell(tester);
      await _scroll(tester, 260);
      expect(_alpha(tester), greaterThan(0.5));

      await tester.tap(find.text('حسابي').last);
      await _settle(tester);
      expect(_alpha(tester), 0, reason: 'الزجاجُ باقٍ فوق تبويبٍ لم يُمرَّر');
    });

    testWidgets('**والتمويهُ يُطفأ معهما فلا تبيضّ حافّتُه**', (tester) async {
      // **وهذا عيبٌ رأيتُه في الرسم لا في الشيفرة.** `BackdropFilter` يأخذ ما
      // خلفه من داخل قصّه وحده، وعند حافّة القصّ يخلط اللونَ بالشفافيّة —
      // فيخرج الشريطُ كلُّه **أفتحَ من الصفحة** وهو بلا سطحٍ أصلاً. وكان
      // القديمُ يخفي ذلك تحت سطحٍ أبيضَ دائم.
      await _openShell(tester);
      expect(_blur(tester), 0.0,
          reason: 'تمويهٌ يعمل بلا سطح — فتبيضّ حافّتُه فوق شاشةٍ لم تُمرَّر');
      await _scroll(tester, 260);
      expect(_blur(tester), greaterThan(10),
          reason: 'سطحٌ بلا تمويهٍ — ورقةٌ باهتةٌ لا زجاج');
    });

    testWidgets('ويعودان بالرجوع إلى الأعلى', (tester) async {
      await _openShell(tester);
      await _scroll(tester, 260);
      await _scroll(tester, -400);
      expect(_alpha(tester), 0);
    });
  });

  group('المحتوى يبدأ تحته', () {
    test('**فالمسافةُ أوسعُ من الشريط نفسِه**', () {
      // وهي شرطُ سلامةٍ لا ذوق: الرأسُ بلا سطحٍ في الأعلى، فلو بدأ المحتوى
      // تحته مباشرةً لَوقع الرمزُ الحبريُّ على أوّل بطاقةٍ نبيذيّةٍ بلا زجاجٍ
      // يفصله.
      expect(glassHeaderSpace, greaterThan(glassHeaderBar));
    });

    testWidgets('**وأوّلُ ما يُرسم يقع تحت حافّته**', (tester) async {
      // ولا يُكتفى بالثابت: القوائمُ هي التي تستعمله، وقائمةٌ تنسى الحشوةَ
      // تبدأ تحت الزجاج.
      await _openShell(tester);
      final bar = tester.getRect(find.byType(GlassHeader));
      final firstCard = tester.getRect(find.byType(PageView));
      expect(firstCard.top, greaterThanOrEqualTo(bar.bottom),
          reason: 'أوّلُ بطاقةٍ تبدأ خلف الزجاج');
    });
  });

  group('الألوانُ مقيسة', () {
    // العتباتُ من WCAG: ‎٤٫٥‎ للنصّ العاديّ، و‎٣‎ للرموز الكبيرة. وتُؤخذ هنا
    // ‎٤٫٥‎ للاثنين.
    //
    // **والألوانُ تُؤخذ من الشريط المرسوم لا من لوح الألوان.** كتبتُ هذه
    // المجموعةَ أوّلاً تسأل `AppColors.ink2` مباشرةً — فكانت تمرّ وإن صُبغ
    // رمزُ الشريط أبيضَ، لأنّها لا تعرف بأيّ لونٍ رُسم. تقيس شيئاً يشبه
    // المقصودَ لا المقصودَ نفسَه.
    testWidgets('**الحبرُ والرمزُ يُقرآن على أرضيّة الصفحة**', (tester) async {
      await _openShell(tester);
      expect(_ratio(_titleColour(tester), AppColors.page), greaterThan(4.5));
      expect(_ratio(_iconColour(tester), AppColors.page), greaterThan(4.5));
    });

    testWidgets('**ويُقرآن على الزجاج وتحته البطاقةُ النبيذيّة**',
        (tester) async {
      // وهذه هي الحالُ الحرجة: أوّلُ ما يمرّ تحت الرأس في الرئيسية بطاقةُ
      // الخطة، وهي أغمقُ ما في الشاشة. والزجاجُ يُقرأ بشفافيّته المرسومة —
      // فلو رُقّق حتى صار ماءً سقط هذا الاختبارُ معه.
      await _openShell(tester);
      await _scroll(tester, 260);
      final glass = _over(_surface(tester).color!, AppColors.accent);
      expect(_ratio(_titleColour(tester), glass), greaterThan(4.5));
      expect(_ratio(_iconColour(tester), glass), greaterThan(4.5));
    });

    test('**والأبيضُ لا يصلح لهما — ولذلك ليسا أبيضين**', () {
      // ضابطٌ على المقياس نفسِه: لو كان يقبل أيّ لونٍ لَما كشف شيئاً.
      final glass = _over(Colors.white.withValues(alpha: 0.82), AppColors.accent);
      expect(_ratio(Colors.white, AppColors.page), lessThan(4.5));
      expect(_ratio(Colors.white, glass), lessThan(4.5));
    });
  });

  group('الأيقونات', () {
    testWidgets('**بلا قرصٍ أبيضَ تحتها**', (tester) async {
      // قرصان وحبّتا عددٍ في ستٍّ وتسعين بكسلاً — أربعةُ أشكالٍ متجاورة.
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: GlassHeader(
          title: 'الرئيسية',
          start: BellIconButton(unread: 12, onTap: () {}),
          end: ChatIconButton(unread: 3, onTap: () {}),
        ),
      )));
      await tester.pump();

      for (final button in tester.widgetList<IconButton>(find.descendant(
          of: find.byType(GlassHeader), matching: find.byType(IconButton)))) {
        final fill = button.style?.backgroundColor
            ?.resolve(const <WidgetState>{});
        expect(fill == null || fill.a == 0, isTrue,
            reason: 'عاد القرصُ الأبيضُ تحت الرمز');
      }
    });

    testWidgets('وحبّةُ العدد على ركن الرمز لا خارجه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: GlassHeader(
          title: 'الرئيسية',
          start: BellIconButton(unread: 12, onTap: () {}),
        ),
      )));
      await tester.pump();

      final dot = tester.getRect(find.byType(UnreadDot));
      final glyph = tester.getRect(find.byIcon(Icons.notifications_none_rounded));
      // تلمس الرمزَ أو تتداخل معه — لا تطفو بعيداً عنه.
      expect(dot.overlaps(glyph.inflate(2)), isTrue,
          reason: 'الحبّةُ تطفو بعيداً عن رمزها');
    });
  });
}
