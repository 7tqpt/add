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
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account_extras.dart';
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
}
