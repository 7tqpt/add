// أربعةُ إصلاحاتٍ جاءت من لقطاتِ شاشةٍ على جهازٍ حقيقيّ.
//
//   ١. **الصورةُ كانت تُعرض مرّتين** في تفاصيل الخدمة: غلافٌ في الأعلى
//      ومعرضٌ تحته أوّلُ صورِه هي الغلافُ نفسُه. وخدمةٌ لها صورةٌ واحدةٌ
//      تملأ نصفَ الشاشة بنسختين منها.
//   ٢. **ولوحةُ القفل كانت ثابتةَ المقاس** — اثنان وسبعون بكسلاً مهما اتّسعت
//      الشاشة، فتخرج على جوالٍ عريضٍ لوحةً صغيرةً محشورةً في وسط فراغ.
//   ٣. **ومهلةُ القفل كانت تُختار**، وأشيعُها «بعد ربع ساعة» — أي أنّ من أخذ
//      الجوالَ من يد صاحبه يقرأ كلَّ شيءٍ ما لم تمضِ خمسَ عشرةَ دقيقة.
//   ٤. **وعلامةُ التوثيق كانت نبيذيّة** — والزرقاءُ عرفٌ يعرفه الناسُ من كلّ
//      تطبيقٍ استعملوه، فيقرؤونها في لمحةٍ بلا حرف.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/app_version.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account.dart';
import 'package:aras/src/screens/account_extras.dart';
import 'package:aras/src/screens/customer_shell.dart';
import 'package:aras/src/screens/home.dart';
import 'package:aras/src/screens/lock.dart';
import 'package:aras/src/screens/service_detail.dart';
import 'package:aras/src/ui/kit.dart';
import 'package:aras/src/ui/media.dart';
import 'package:aras/src/ui/service_card.dart';

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

/// نبضٌ حتى تسكن الشاشة — والنبضةُ الوسطى للمؤقّتات لا للحركة.
///
/// `pumpAndSettle` لا تُقدّم الساعةَ إلّا ما دام إطارٌ مجدولاً، ومؤقّتُ قراءةٍ
/// لا يجدول شيئاً حتى يحين. فتُدسّ نبضةُ ثانيةٍ بينهما.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _screen(WidgetTester tester, {double width = 1080, double height = 2400}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ==========================================================================
  //  ١) الصورةُ لا تُعرض مرّتين
  // ==========================================================================

  group('غلافُ الخدمة', () {
    testWidgets('**لا يُرسم مرّتين — غلافاً ومعرضاً**', (tester) async {
      _screen(tester);
      await tester.pumpWidget(_wrap(const ServiceDetailScreen(
        serviceId: 's1',
        coverPath: 'services/s1/cover.jpg',
      )));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // خدمةُ العرض التجريبيّة لها صورةٌ واحدة. وقبل الإصلاح كانت تُبنى
      // مرّتين: `MediaThumb` في الغلاف، و`MediaThumb` أوّلَ المعرض.
      expect(
        find.byType(MediaThumb),
        findsOneWidget,
        reason: 'عُرضت الصورةُ نفسُها مرّتين متلاصقتين',
      );
    });

    testWidgets('ويبقى موضعُ الطيران في أوّل إطار', (tester) async {
      // **ووقتُ التحميل هو وقتُ الانتقال بعينه**، فلو غاب الغلافُ عن أوّل
      // إطارٍ لَطار من البطاقة إلى فراغٍ وارتدّ.
      _screen(tester);
      await tester.pumpWidget(_wrap(const ServiceDetailScreen(
        serviceId: 's1',
        coverPath: 'services/s1/cover.jpg',
      )));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
            (w) => w is Hero && w.tag == serviceHeroTag('s1')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 2));
    });
  });

  // ==========================================================================
  //  ٢) لوحةُ القفل تكبر بكِبَر الشاشة
  // ==========================================================================

  group('لوحةُ القفل', () {
    Future<double> keyWidth(WidgetTester tester, double physicalWidth) async {
      _screen(tester, width: physicalWidth);
      await tester.pumpWidget(_wrap(
        LockScreen(lock: AppLock(), onSignOut: () async {}),
      ));
      await tester.pumpAndSettle();
      return tester.getSize(find.byKey(const ValueKey('pad-5'))).width;
    }

    testWidgets('**تكبر بكِبَر الشاشة — ويُقاس بالفرق لا بحدٍّ**',
        (tester) async {
      // **وأوّلُ صياغةٍ لهذا الاختبار طلبت «أكبرَ من سبعين».** والمقاسُ
      // الثابتُ الذي أردنا منعَه كان اثنين وسبعين — فمرّ من تحت الحدّ،
      // وبقي الاختبارُ أخضرَ حين أُعيد المقاسُ الثابت عمداً. وكشفه ضابطٌ
      // سالب.
      //
      // والمقصودُ ليس رقماً بل **علاقة**: شاشةٌ أوسعُ ⇐ مفتاحٌ أوسع. ولا
      // مقاسَ ثابتٍ يمرّ من هذا مهما كان.
      final narrow = await keyWidth(tester, 900);
      final wide = await keyWidth(tester, 1400);
      expect(wide, greaterThan(narrow),
          reason: 'المقاسُ واحدٌ في الشاشتين — أي أنّه ثابت');
    });

    testWidgets('**ولا تتمدّد بلا حدٍّ على شاشةٍ عريضة**', (tester) async {
      // مفتاحٌ أعرضُ من الإبهام يُبعد الرقمَ عن الرقم، فتُدخَل أربعةُ أرقامٍ
      // بحركةِ يدٍ كاملةٍ لا بإبهام.
      final wide = await keyWidth(tester, 2400);
      expect(wide, lessThanOrEqualTo(104));
    });

    testWidgets('وكلُّ مفاتيحها موجودةٌ ومضغوطة', (tester) async {
      _screen(tester);
      await tester.pumpWidget(_wrap(
        LockScreen(lock: AppLock(), onSignOut: () async {}),
      ));
      await tester.pumpAndSettle();
      for (final d in ['0', '1', '5', '9', 'back']) {
        expect(find.byKey(ValueKey('pad-$d')), findsOneWidget, reason: d);
      }
    });
  });

  // ==========================================================================
  //  ٣) لا مهلةَ تُختار
  // ==========================================================================

  group('مهلةُ القفل', () {
    testWidgets('**ولا تُعرض خياراتُ مهلةٍ في الإعدادات**', (tester) async {
      // **وتُبنى شاشةُ الإعدادات الحقيقيّة.** أوّلُ صياغةٍ لهذا الاختبار
      // بنَت `Scaffold` فيها كلمةُ «الإعدادات» ثمّ سألت عن الأزرار الغائبة —
      // فمرّت وهي لا تقيس شيئاً على الإطلاق.
      _screen(tester);
      lockStorageOverride = <String, String>{};
      addTearDown(() => lockStorageOverride = null);
      await lockSetPin('1111');
      await appLock.boot();

      await tester.pumpWidget(_wrap(SettingsScreen(session: Session())));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // والقفلُ مفعَّلٌ هنا — وهي الحالُ التي كانت تُعرض فيها الأزرار.
      expect(appLock.enabled, isTrue, reason: 'الاختبارُ لا يقيس ما يدّعي');
      expect(find.text('قفل التطبيق', skipOffstage: false), findsOneWidget);

      for (final gone in [
        'بعد دقيقة',
        'بعد خمس دقائق',
        'بعد ربع ساعة',
        'بعد ساعة',
      ]) {
        expect(find.text(gone, skipOffstage: false), findsNothing, reason: gone);
      }
      await appLock.disable();
    });

    test('**والقفلُ فورَ المغادرة لا بعدها بمدّة**', () async {
      lockStorageOverride = <String, String>{};
      addTearDown(() => lockStorageOverride = null);

      await lockSetPin('1111');
      final lock = AppLock();
      await lock.boot();
      await lock.unlock('1111');

      lock.onLeave();
      lock.onReturn();
      expect(lock.locked, isTrue, reason: 'غادر التطبيقُ ولم يُقفل');
    });
  });

  // ==========================================================================
  //  ٦) رقمُ النسخة — **يُقرأ من الثابت لا يُكتب بيده**
  // ==========================================================================

  group('رقمُ النسخة', () {
    test('**لا يُكتب رقمٌ بيده في سطر الإصدار**', () {
      // **وهذا ما كان.** كان في شاشتين «الإصدار 1.0.0» مكتوبةً حرفاً، فبقي
      // على ١٫٠٫٠ ثماني نسخٍ متتالية. وصاحبُ الجهاز لا يملك أن يعرف أيَّ
      // حزمةٍ يشغّل — **ولا نحن**: سُئلنا «عدّلتَ الأيقونات ولم تتغيّر»،
      // ولا سبيلَ إلى الجواب إلّا أن يُعرف ما في يده.
      expect(appVersionLabel, contains(appVersionName));
      expect(appVersionLabel, contains('$appBuild'));
      expect(appVersionLabel, isNot(contains('1.0.0')),
          reason: 'ما لم تكن النسخةُ ١٫٠٫٠ فعلاً');
    });

    testWidgets('**ويُعرض في «حسابي» كما هو**', (tester) async {
      _screen(tester);
      // و`AccountScreen` جسمُ تبويبٍ لا شاشةٌ كاملة، فتحتاج `Material`
      // فوقها كما تجدها في القشرة.
      await tester.pumpWidget(_wrap(
        Scaffold(body: AccountScreen(session: Session())),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(appVersionLabel, skipOffstage: false), findsOneWidget,
          reason: 'سطرُ الإصدار لا يقول ما في الحزمة');
    });

    testWidgets('وفي الإعدادات كذلك', (tester) async {
      _screen(tester);
      await tester.pumpWidget(_wrap(SettingsScreen(session: Session())));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(appVersionLabel, skipOffstage: false), findsOneWidget);
    });
  });

  // ==========================================================================
  //  ٥) الأيقونات — **ولا تتشابه اثنتان**
  // ==========================================================================

  group('الأيقونات', () {
    // أسماءُ الأقسام كما في `supabase/seed.sql`.
    const slugs = [
      'halls', 'catering', 'artists', 'sound', 'photography', 'support',
      'cars', 'attire', 'planners', 'beauty', 'decor', 'printing',
    ];

    test('**ولا يتكرّر رمزٌ بين قسمين**', () {
      // **وهذا ما ينكسر بصمت.** رمزان متشابهان في شبكةٍ من اثنتَي عشرةَ
      // بطاقةً يجعلان صاحبَها يفتح «الطباعة» وهو يريد «التصوير» — ولا يظهر
      // ذلك في مراجعةِ شيفرةٍ لأنّ كلَّ سطرٍ صحيحٌ على حدة.
      final seen = <IconData, String>{};
      for (final slug in slugs) {
        final icon = categoryIcon(slug);
        expect(seen[icon], isNull,
            reason: 'الرمزُ نفسُه في «$slug» و«${seen[icon]}»');
        seen[icon] = slug;
      }
    });

    test('ولا قسمَ يقع على الرمز الاحتياطيّ', () {
      // الاحتياطيُّ لِما يُضاف من اللوحة غداً، لا لأقسامنا الاثنَي عشر.
      for (final slug in slugs) {
        expect(categoryIcon(slug), isNot(Icons.category_outlined), reason: slug);
      }
      expect(categoryIcon('ما-لا-نعرفه'), Icons.category_outlined);
    });

    test('**والأقسامُ لا تأخذ رموزَ شريط التنقّل**', () {
      // بطاقةُ قسمٍ برمز التبويب تُقرأ تبويباً، فتُضغط لتنتقل لا لتُرشِّح.
      const nav = [
        Icons.home_outlined,
        Icons.receipt_long_outlined,
        Icons.search_outlined,
        Icons.fact_check_outlined,
        Icons.person_outline,
      ];
      for (final slug in slugs) {
        expect(nav, isNot(contains(categoryIcon(slug))), reason: slug);
      }
    });

    testWidgets('**ولا يتشابه رمزان في شريط التنقّل**', (tester) async {
      // كان «حجوزاتي» تقويماً و«خطة العرس» تقويماً آخرَ يجاوره — أيقونتان
      // متشابهتان في أربعةٍ وعشرين بكسلاً، فيضغط صاحبُها إحداهما يقصد
      // الأخرى.
      _screen(tester);
      await tester.pumpWidget(_wrap(CustomerShell(session: Session())));
      // **ولا يُكتفى بنبضتين.** الرئيسيةُ قائمةٌ كسولة: ما نزل تحت الطيّة لا
      // يُبنى أصلاً. فلمّا حُذف حقلُ البحث والترحيب صعد ما تحتهما إلى داخل
      // الشاشة، فبدأ قراءةً مؤجَّلةً بمؤقّتٍ يُنشأ في آخر نبضة ولا يجد ما
      // يُشغّله — فسقط الاختبارُ بـ«مؤقّتٌ معلّق» وهو لا يقيس مؤقّتاً.
      await _settle(tester);

      // **وتُقرأ الرموزُ المرسومةُ تحت الشريط نفسِه** لا قائمةُ الإعدادات:
      // `GlassNavItem` صنفُ بياناتٍ لا عنصرُ شجرة، وقائمةٌ صحيحةٌ قد تُرسم
      // خطأً. والمقصودُ ما يراه صاحبُ الشاشة.
      final icons = tester
          .widgetList<Icon>(find.descendant(
              of: find.byType(GlassNavBar), matching: find.byType(Icon)))
          .map((i) => i.icon)
          .toList();
      expect(icons.length, 5, reason: 'تبدّل عددُ التبويبات المرسومة');
      expect(icons.toSet().length, icons.length,
          reason: 'رمزان متطابقان في الشريط — يُضغط أحدُهما ويُقصد الآخر');
    });
  });

  // ==========================================================================
  //  ٤) علامةُ التوثيق زرقاء
  // ==========================================================================

  group('علامةُ التوثيق', () {
    testWidgets('**زرقاءُ لا نبيذيّة**', (tester) async {
      // **وهذا خروجٌ عن لوح الألوان عن قصد.** الزرقاءُ عرفٌ تعلّمه الناسُ من
      // فيسبوك وإنستغرام وتويتر، فيقرؤونه بلا حرف. وصبغُها بلون الهويّة
      // يجعلها زخرفةً أخرى في شاشةٍ نبيذيّةٍ كلُّها — تُرى ولا تُفهم.
      _screen(tester);
      await tester.pumpWidget(_wrap(
        const Scaffold(body: Center(child: VerifiedMark(size: 40))),
      ));
      await tester.pump();

      final mark = tester.widget<VerifiedMark>(find.byType(VerifiedMark));
      expect(mark.color, verifiedBlue);
      // وأزرقُ فعلاً لا اسماً: الأزرقُ أغلبُ قنواته.
      expect(verifiedBlue.b, greaterThan(verifiedBlue.r));
      expect(verifiedBlue.b, greaterThan(verifiedBlue.g));
      expect(mark.color, isNot(AppColors.accent),
          reason: 'بقيت نبيذيّةً تُرى ولا تُفهم');

      // وتُرسم قرصاً مسنَّناً لا دائرةً صمّاء.
      expect(
        find.descendant(
            of: find.byType(VerifiedMark), matching: find.byType(CustomPaint)),
        findsWidgets,
      );

      // ولها صحٌّ أبيضُ في وسطها — والقرصُ وحده لا يقول «موثَّق».
      final check = tester.widget<Icon>(find.descendant(
        of: find.byType(VerifiedMark),
        matching: find.byIcon(Icons.check_rounded),
      ));
      expect(check.color, Colors.white);
    });

    testWidgets('وحجمُها من حجم ما تجاوره', (tester) async {
      _screen(tester);
      await tester.pumpWidget(_wrap(const Scaffold(
        body: Column(children: [
          VerifiedMark(size: 13),
          VerifiedMark(size: 40),
        ]),
      )));
      await tester.pump();
      final sizes = tester
          .widgetList<SizedBox>(find.descendant(
              of: find.byType(VerifiedMark), matching: find.byType(SizedBox)))
          .map((b) => b.width)
          .toList();
      expect(sizes, containsAll(<double>[13, 40]));
    });
  });

  // ==========================================================================
  //  ٥) بطاقةُ القسم: أرضيّةٌ بيضاء، وقرصٌ زجاجيّ، والأقراصُ في خطٍّ مستقيم
  // ==========================================================================

  group('اسمُ القسم يُشقّ', () {
    test('**عند أوّل واو — أصلٌ غامقٌ وتتمّةٌ تحته**', () {
      expect(splitCategoryLabel('القاعات والخيام'),
          (head: 'القاعات', tail: 'والخيام'));
      expect(splitCategoryLabel('الطبخ والضيافة'),
          (head: 'الطبخ', tail: 'والضيافة'));
      expect(splitCategoryLabel('الموية والطليع والخدمات المساندة'),
          (head: 'الموية', tail: 'والطليع والخدمات المساندة'));
    });

    test('ولا يُشقّ ما لا واوَ فيه', () {
      expect(splitCategoryLabel('السيارات'), (head: 'السيارات', tail: ''));
      expect(splitCategoryLabel('الكل'), (head: 'الكل', tail: ''));
      expect(splitCategoryLabel('منظمي الحفلات'),
          (head: 'منظمي الحفلات', tail: ''));
    });

    test('**ولا يُترك أصلٌ من حرفٍ ولا تتمّةٌ من حرفين**', () {
      // **أصلٌ من حرفٍ واحد.** «و وكذا» تُشقّ إلى «و» فوق «وكذا» — سطرٌ
      // أعلاه لا يقول شيئاً. وكان الشرطُ `at <= 0` يُراد به «واوٌ في أوّل
      // الاسم» وهو ميّتٌ: الاسمُ يُقلَّم قبله فلا يبدأ بفراغ. كشفه ضابطٌ
      // سالبٌ كسرتُه فلم يسقط شيء.
      expect(splitCategoryLabel('و وكذا'), (head: 'و وكذا', tail: ''));
      expect(splitCategoryLabel(' وكذا'), (head: 'وكذا', tail: ''));
      // تتمّةٌ من حرفين: سطرٌ لا يقول شيئاً، فيبقى الاسمُ كما هو.
      expect(splitCategoryLabel('شيء وا'), (head: 'شيء وا', tail: ''));
    });
  });

  group('بطاقةُ القسم', () {
    // البطاقاتُ الاثنتا عشرةَ بأسمائها الحقيقيّة — وفيها أطولُ اسمٍ في
    // البذرة، وهو الذي يفيض إن فاض شيء.
    const names = [
      ('halls', 'القاعات والخيام'),
      ('catering', 'الطبخ والضيافة'),
      ('artists', 'الفنانين والفرق'),
      ('sound', 'الصوت والمعدات'),
      ('photography', 'التصوير والإضاءة'),
      ('support', 'الموية والطليع والخدمات المساندة'),
      ('cars', 'السيارات'),
      ('attire', 'الملبوسات'),
      ('planners', 'منظمي الحفلات'),
      ('beauty', 'التجميل والكوافير'),
      ('decor', 'الديكور والورود'),
      ('printing', 'الطباعة والدعوات'),
      // **أصلٌ طويلٌ وله تتمّة** — وليس في البذرة اليوم مثلُه، فلولاه لَبقي
      // شرطُ «سطرٌ واحدٌ للأصل ما دامت له تتمّة» بلا قياس: كسرتُه فلم يسقط
      // شيء. وأصلٌ يُلفّ سطرين فوق تتمّةٍ من سطرين يفيض على شاشة ٣٢٠.
      ('planners', 'منظمي الحفلات والمناسبات'),
    ];

    Widget grid() => Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.sm,
            // النسبةُ نفسُها المكتوبةُ في `home.dart` — ولو بُدّلت هناك
            // وحدها لَبقي هذا الاختبار يقيس هندسةً غيرَ التي تُعرض.
            childAspectRatio: 0.62,
            children: [
              for (final (slug, name) in names)
                CategoryCard(
                  label: name,
                  icon: categoryIcon(slug),
                  tone: categoryTone(slug),
                  active: false,
                  width: null,
                  onTap: () {},
                ),
            ],
          ),
        );

    // **والشاشةُ الضيّقةُ هي التي تفيض لا الواسعة.** ٣٢٠ منطقيّاً أضيقُ ما
    // يُباع، والخليةُ فيه ٦٦ عرضاً لا ٧٦ — فيلتفّ الاسمُ أكثرَ ويطول.
    for (final w in [960.0, 1080.0, 1200.0]) {
      testWidgets('**لا تفيض عند عرض ${w ~/ 3} منطقيّاً**', (tester) async {
        _screen(tester, width: w);
        await tester.pumpWidget(_wrap(Scaffold(body: grid())));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('**والأقراصُ كلُّها في خطٍّ واحدٍ داخل الصفّ**',
        (tester) async {
      _screen(tester);
      await tester.pumpWidget(_wrap(Scaffold(body: grid())));
      await tester.pump(const Duration(milliseconds: 600));

      // القرصُ هو أوّلُ `Container` مربّعٍ ٣٤×٣٤ في كلّ بطاقة.
      //
      // **والصفُّ يُعرف بترتيب البطاقة لا بقربها من جارتها.** جمعتُها أوّلاً
      // بتقريب الإحداثيّ الرأسيّ، فكانت بطاقةٌ تنزل عن صفّها فتصير مجموعةً
      // وحدها — والفرقُ في مجموعةٍ من واحدةٍ صفرٌ دائماً، فيمرّ الاختبار
      // وهو لا يقيس شيئاً. كشفه ضابطٌ سالبٌ كسرتُه فلم يسقط.
      final tops = <int, List<double>>{};
      var i = 0;
      for (final e in tester.widgetList<CategoryCard>(find.byType(CategoryCard))) {
        final card = find.byWidget(e);
        final disc = find
            .descendant(of: card, matching: find.byType(Container))
            .evaluate()
            .map((el) => el.renderObject!)
            .whereType<RenderBox>()
            .firstWhere((r) => r.size.width == 34 && r.size.height == 34);
        tops.putIfAbsent(i++ ~/ 4, () => []).add(disc.localToGlobal(Offset.zero).dy);
      }
      expect(tops, isNotEmpty);
      for (final row in tops.values) {
        // **الفرقُ صفرٌ لا «قريبٌ من صفر».** لو تبع القرصُ طولَ الاسم
        // لَاختلف بين «السيارات» و«الموية والطليع…» في الصفّ الواحد.
        expect(row.reduce((a, b) => a > b ? a : b) - row.reduce((a, b) => a < b ? a : b),
            0.0);
      }
    });

    testWidgets('**وأصلُ الاسمِ سطرٌ واحدٌ ما دامت له تتمّة**', (tester) async {
      // **والقرصُ وحدَه لا يكفي دليلاً.** هو أوّلُ ما في العمود فلا يتحرّك
      // مهما فعل الاسمُ تحته — قِستُه فبقي في مكانه حتى مع كسر الحدّ.
      //
      // **وموضعُ التتمّة لا يصلح دليلاً كذلك.** جرّبتُه فسقط: أعلى التتمّة
      // يختلف بكسلٍ واحدٍ بين «القاعات» و«منظمي الحفلات» في الشيفرة
      // الصحيحة نفسِها — لأنّ ارتفاع السطر يتبع حروفَه. فاختبارُ تساوٍ
      // تامٍّ كان يمرّ بالمصادفة لا بالصحّة.
      //
      // فيُقاس ما يقوله الحدُّ بعينه: **ارتفاعُ الأصل**. سطرٌ واحدٌ عند
      // ١١٫٥ في ١٫٢٥ نحوُ ١٥، وسطران نحوُ ٣٠ — والعشرون بينهما بمنأى عن
      // الاثنين، لا رقمٌ مضبوطٌ على النتيجة.
      _screen(tester, width: 960);
      await tester.pumpWidget(_wrap(Scaffold(body: grid())));
      await tester.pump(const Duration(milliseconds: 600));

      var measured = 0;
      for (final e in tester.widgetList<CategoryCard>(find.byType(CategoryCard))) {
        final parts = splitCategoryLabel(e.label);
        if (parts.tail.isEmpty) continue; // بلا تتمّة: سطران مسموحان
        final head = find
            .descendant(of: find.byWidget(e), matching: find.byType(Text))
            .evaluate()
            .firstWhere((el) => (el.widget as Text).data == parts.head);
        measured++;
        expect((head.renderObject! as RenderBox).size.height, lessThan(20.0),
            reason: 'أصلُ «${e.label}» لُفّ سطرين وتحته تتمّة');
      }
      // **وأنّ شيئاً قِيس أصلاً** — وإلّا مرّ الاختبارُ بلا حلقةٍ تدور.
      expect(measured, greaterThan(4));
    });

    testWidgets('**وأرضيّتُها بيضاءُ لا مصبوغةٌ بلون القسم**', (tester) async {
      _screen(tester);
      await tester.pumpWidget(_wrap(Scaffold(
        body: Center(
          child: CategoryCard(
            label: 'القاعات والخيام',
            icon: categoryIcon('halls'),
            tone: categoryTone('halls'),
            active: false,
            onTap: () {},
          ),
        ),
      )));
      await tester.pump(const Duration(milliseconds: 600));

      final box = tester
          .widgetList<AnimatedContainer>(find.descendant(
              of: find.byType(CategoryCard),
              matching: find.byType(AnimatedContainer)))
          .first;
      final d = box.decoration! as BoxDecoration;
      expect(d.color, Colors.white);
      // ولا تدرّجَ يصبغها: التدرّجُ كان يملأ البطاقة كلَّها بلون القسم.
      expect(d.gradient, isNull);
    });
  });

  // ==========================================================================
  //  ٥) «خدماتٌ لك» — بطاقتان في السطر
  // ==========================================================================

  group('خدماتٌ لك', () {
    Future<void> open(WidgetTester tester, {double width = 1080}) async {
      _screen(tester, width: width, height: 3000);
      await tester.pumpWidget(_wrap(CustomerShell(session: Session())));
      await _settle(tester);
      // القسمُ تحت الطيّة: يُنزل إليه لا يُفترض أنّه مرسوم.
      await tester.dragFrom(
        tester.getCenter(find.byType(GlassNavBar)) - const Offset(0, 300),
        const Offset(0, -420),
      );
      await _settle(tester);
      // **ولا يُقاس قسمٌ خارج الشاشة.** لو لم يبلغه التمريرُ لَمرّ اختبارُ
      // الفيض فارغاً — لا فيضَ فيما لا يُرسم.
      expect(find.byType(MediaThumb), findsWidgets,
          reason: 'لم يبلغ التمريرُ «خدماتٌ لك»');
    }

    /// البطاقاتُ في مجموعاتٍ حسب سطرها — بتقارب المركز الرأسيّ.
    List<List<Rect>> rows(WidgetTester tester) {
      final boxes = find
          .byType(MediaThumb)
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)))
          .toList()
        ..sort((a, b) => a.center.dy.compareTo(b.center.dy));
      final out = <List<Rect>>[];
      for (final r in boxes) {
        if (out.isNotEmpty && (out.last.first.center.dy - r.center.dy).abs() < 8) {
          out.last.add(r);
        } else {
          out.add([r]);
        }
      }
      return out;
    }

    testWidgets('**بطاقتان في السطر لا واحدة**', (tester) async {
      // **ويُقاس الرسمُ لا عددُ الأبناء.** صفٌّ فيه بطاقتان قد يُرسم واحدةً
      // فوق أخرى لو ضاق، فالمقصودُ أن تقعا في سطرٍ واحدٍ فعلاً.
      await open(tester);
      final lines = rows(tester);
      expect(lines, isNotEmpty, reason: 'لا بطاقاتِ خدماتٍ في الشاشة');
      expect(lines.first.length, 2, reason: 'السطرُ الأوّل ليس فيه بطاقتان');
      // وعرضُهما واحد: بطاقةٌ أعرضُ من جارتها تُقرأ صنفاً آخر.
      expect((lines.first[0].width - lines.first[1].width).abs(), lessThan(1.0));
    });

    testWidgets('**وأربعٌ لا ثلاث — فلا تبقى خليّةٌ فارغة**', (tester) async {
      await open(tester);
      final lines = rows(tester);
      expect(lines.length, greaterThanOrEqualTo(2));
      expect(lines[0].length + lines[1].length, 4);
    });

    testWidgets('**والبطاقتان متساويتا الارتفاع في السطر**', (tester) async {
      // اسمٌ في سطرين وجارُه في سطرٍ واحد يجعل البطاقتين متفاوتتين، فيتعرّج
      // السطرُ وتبدو إحداهما ناقصة. و`IntrinsicHeight` يسوّيهما بأطولهما.
      await open(tester);
      final cards = find.byType(Card).evaluate().map((e) => tester.getRect(find.byWidget(e.widget))).toList();
      final pairs = <List<Rect>>[];
      for (final r in cards) {
        if (pairs.isNotEmpty && (pairs.last.first.center.dy - r.center.dy).abs() < 8) {
          pairs.last.add(r);
        } else {
          pairs.add([r]);
        }
      }
      final full = pairs.where((p) => p.length == 2);
      expect(full, isNotEmpty, reason: 'لا سطرَ فيه بطاقتان');
      for (final p in full) {
        expect((p[0].height - p[1].height).abs(), lessThan(0.5),
            reason: 'بطاقتان في سطرٍ واحدٍ مختلفتا الارتفاع');
      }
    });

    testWidgets('**وعلى كلّ بطاقةٍ قلبُ المفضّلة**', (tester) async {
      await open(tester);
      final hearts = find.descendant(
        of: find.byType(Card),
        matching: find.byIcon(Icons.favorite_border),
      );
      // أربعُ بطاقاتٍ فأربعةُ قلوب — لا واحدٌ على الأولى وحدها.
      expect(hearts, findsNWidgets(4));
    });

    testWidgets('**والضغطُ عليه يحفظ ولا يفتح صفحةَ الخدمة**', (tester) async {
      // **وهذا هو العطبُ الذي يقع بلا حارس:** البطاقةُ كلُّها تفتح الصفحة،
      // فقلبٌ فوقها بلا حَلبةِ إيماءاتٍ خاصّةٍ به يُضغط فتُفتح الصفحةُ ولا
      // يُحفظ شيء — والإصبعُ لا يفرّق.
      await open(tester);
      final heart = find
          .descendant(
            of: find.byType(Card),
            matching: find.byIcon(Icons.favorite_border),
          )
          .first;
      await tester.tap(heart);
      await _settle(tester);

      expect(find.byType(ServiceDetailScreen), findsNothing,
          reason: 'الضغطةُ على القلب فتحت صفحةَ الخدمة');
      // وامتلأ قلبٌ واحدٌ لا غير.
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.byIcon(Icons.favorite),
        ),
        findsOneWidget,
        reason: 'الضغطةُ لم تُبدّل القلب',
      );
    });

    // **والشاشةُ الضيّقةُ هي التي تفيض لا الواسعة.**
    for (final w in [960.0, 1080.0, 1200.0]) {
      testWidgets('**لا تفيض عند عرض ${w ~/ 3} منطقيّاً**', (tester) async {
        await open(tester, width: w);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ==========================================================================
  //  ٦) مساحةُ الإعلان في أعلى الرئيسية
  // ==========================================================================

  group('اللافتاتُ الإعلانيّة', () {
    Future<void> open(WidgetTester tester) async {
      _screen(tester, height: 3000);
      await tester.pumpWidget(_wrap(CustomerShell(session: Session())));
      await _settle(tester);
    }

    testWidgets('**بمقاس البطاقتين اللتين كانتا هنا**', (tester) async {
      // «بنفس حجم البطاقة» — والرقمُ ‎١٩٦‎ هو ارتفاعُ `PageView` نفسِه لا
      // ارتفاعُ اللافتة داخله، فيُقاس الشريطُ لا ما فيه.
      await open(tester);
      expect(tester.getSize(find.byType(PageView)).height, 196);
    });

    testWidgets('**وعليها «إعلان» صراحةً**', (tester) async {
      // مساحةٌ مدفوعةٌ تُعرض كأنّها اختيارُ المنصّة تخدع من يقرؤها.
      await open(tester);
      expect(
        find.descendant(of: find.byType(PageView), matching: find.text('إعلان')),
        findsWidgets,
      );
    });

    testWidgets('**وتدور وحدها كلَّ ثلاث ثوانٍ**', (tester) async {
      // **ويُقاس ما رُسم لا ما جُدول.** مؤقّتٌ يعمل ولا ينتقل شيءٌ لا يفيد،
      // فيُقرأ موضعُ الشريط قبل الثلاث وبعدها.
      await open(tester);
      int at() => tester
          .widget<PageView>(find.byType(PageView))
          .controller!
          .page!
          .round();
      final before = at();

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      final after = at();
      expect(after, isNot(before), reason: 'لم تنتقل اللافتةُ بعد ثلاث ثوانٍ');
    });

    testWidgets('**ولا يُترك مؤقّتُها معلّقاً بعد زوال الشاشة**', (tester) async {
      // مؤقّتٌ دوريٌّ لا يُلغى يُبقي الشاشةَ حيّةً في الذاكرة بعد إغلاقها،
      // وإطارُ الاختبار يُسقط أيَّ اختبارٍ يتركه — وهو محقٌّ.
      await open(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    });

    // ── كلماتُ الإعلان ──────────────────────────────────────────────────
    //
    // وكانت الصورةُ وحدَها تحمل نصَّها، فكلُّ تبديلِ كلمةٍ يحتاج مصمّماً
    // يعيد الصورة.

    testWidgets('**وكلماتُها تُكتب فوقها**', (tester) async {
      await open(tester);
      expect(
        find.descendant(
          of: find.byType(PageView),
          matching: find.text('قاعةُ التاج — خصمُ ٢٠٪ لحجوزات رمضان'),
        ),
        findsWidgets,
      );
    });

    testWidgets('**وتحتها ستارٌ يجعلها تُقرأ على أيّ صورة**', (tester) async {
      // **والستارُ شرطٌ لا زينة.** الصورةُ من صاحب الإعلان ولا نعرف
      // ألوانها: أبيضُ على سماءٍ بيضاءَ في صورةِ قاعةٍ نهاراً لا يُقرأ.
      await open(tester);

      final text = find.text('قاعةُ التاج — خصمُ ٢٠٪ لحجوزات رمضان').first;
      // والستارُ أخٌ للنصّ في الكومة لا جدٌّ له: يُطلب من البطاقة التي
      // تضمّهما، لا من سلسلةِ آباء النصّ.
      final card = find.ancestor(of: text, matching: find.byType(BannerCard)).first;
      final scrims = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: card, matching: find.byType(DecoratedBox)),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient != null);

      expect(scrims, isNotEmpty, reason: 'لا ستارَ تحت الكلمات');

      // والنصُّ أبيضُ على غامق، لا العكس.
      final style = tester.widget<Text>(text).style!;
      expect(style.color, Colors.white);
    });

    testWidgets('**ولافتةٌ بلا كلماتٍ لا يُظلَّم نصفُها بلا سبب**', (tester) async {
      // الثالثةُ في وضع العرض بلا كلمات: ستارٌ يُرسم فوقها يبتلع من الصورة
      // ثلثَها ولا يُظهر حرفاً.
      const bare = PromoBanner(id: 'b#1', imageUrl: 'https://example.invalid/x.jpg');
      await tester.pumpWidget(
        _wrap(const Scaffold(body: SizedBox(height: 196, child: BannerCard(banner: bare)))),
      );
      await tester.pump();

      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient != null);
      expect(gradients, isEmpty);
    });

    testWidgets('**وحملةٌ بصورتين شريحتان لا واحدة**', (tester) async {
      // «أريد أن أضع أكثر من صورةٍ في الإعلان» — والقاعدةُ تفرشها شرائح،
      // فحملتان (إحداهما بصورتين) ثلاثُ شرائح.
      await open(tester);
      final pages = tester.widget<PageView>(find.byType(PageView));
      // و`estimatedChildCount` لا `childCount` بعد قولبة: الشريطُ يُبنى
      // بقائمةِ أبناءٍ فمندوبُه `SliverChildListDelegate`، والقولبةُ إلى
      // `Builder` تسقط — وهي عيبٌ في القياس لا في المقيس.
      expect(pages.childrenDelegate.estimatedChildCount, 3);
    });

    // **وهذا الاختبارُ جاء من ضابطٍ لم يسقط.** كُسر `PromoBanner.fromMap`
    // عمداً — تُهمِل الكلماتِ الواصلةَ من القاعدة — فبقيت الحزمةُ خضراء:
    // وضعُ العرض يبني الطرازَ ثابتاً ولا يمرّ بـ`fromMap` قطّ. أي أنّ كلَّ
    // ما بين القاعدة والشاشة كان بلا حارس.
    test('والطرازُ يقرأ ما يصل من القاعدة', () {
      final banner = PromoBanner.fromMap(const {
        'id': 'abc#2',
        'image_url': 'https://example.invalid/2.jpg',
        'headline': 'خصمُ ٢٠٪',
        'provider_id': 'p1',
        'provider_name': 'قاعة التاج',
      });

      expect(banner.id, 'abc#2');
      expect(banner.imageUrl, 'https://example.invalid/2.jpg');
      expect(banner.headline, 'خصمُ ٢٠٪');
      expect(banner.providerId, 'p1');
      expect(banner.providerName, 'قاعة التاج');
    });

    test('وما نقص من الصفّ لا يُسقط الطراز', () {
      // حملةٌ قديمةٌ كُتبت قبل عمود الكلمات: صفٌّ بلا `headline`. ولو رمى
      // الطرازُ لَسقطت الرئيسيةُ كلُّها على لافتةٍ واحدةٍ ناقصة.
      final banner = PromoBanner.fromMap(const {
        'id': 'old#1',
        'image_url': 'https://example.invalid/old.jpg',
      });

      expect(banner.headline, isEmpty);
      expect(banner.providerId, isEmpty);
    });

    testWidgets('**وكلماتٌ طويلةٌ تُقصّ ولا تبتلع الصورة**', (tester) async {
      await open(tester);
      final text = tester.widget<Text>(
        find.text('قاعةُ التاج — خصمُ ٢٠٪ لحجوزات رمضان').first,
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
