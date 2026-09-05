// المشاركة: ما يُكتب في رسالة واتساب، ومتى يظهر الزرّ ومتى يغيب.
//
// **وأثقلُ ما يُقاس هنا لا يُرى في لقطة:**
//
//   ١. **أنّ الرسالةَ لا تحمل رابطاً مكسوراً.** «حمّل تطبيق فرحتي:» ثمّ فراغٌ
//      تُقرأ عطباً في التطبيق الذي تدعو إليه — وهي تُعاد إرسالُها من يدٍ إلى
//      يد، فالعطبُ يسافر.
//   ٢. **وأنّها لا تحمل ما ليس للعلن.** رقمُ مقدّم الخدمة وبريدُه لم يأذن
//      صاحبُهما بأن يُرسلا في رسالةٍ لا يعرف أين تصل.
//   ٣. **وأنّ ما يخرج هو ما يُقاس.** الفعلُ الحقيقيّ يفتح ورقةَ النظام، ولا
//      نظامَ في الاختبار — فيُلتقط بمقبضٍ يُبدَّل، ويُقرأ النصُّ حرفاً حرفاً.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/share.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/ui/share_button.dart';

const _url = 'https://github.com/x/y/releases/latest';

ServiceItem _service({
  String title = 'قاعة الأندلس',
  String description = 'قاعةٌ واسعةٌ تتّسع لأربعمئة ضيف.',
  num price = 250000,
  num? priceTo,
  String unit = 'ليلة',
  String governorate = 'صنعاء',
}) =>
    ServiceItem(
      id: 's1',
      title: title,
      description: description,
      price: price,
      priceTo: priceTo,
      unit: unit,
      depositPercent: 30,
      categoryId: 'c1',
      categoryName: 'قاعات',
      providerId: 'p1',
      providerName: 'قاعات الأندلس',
      providerGovernorate: governorate,
      providerRating: 4.6,
      providerReviewsCount: 12,
      providerIsFeatured: false,
      cancellationPolicyName: null,
    );

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

void main() {
  // ==========================================================================
  //  الرابط
  // ==========================================================================

  group('الرابط', () {
    test('**لا يُقبل إلّا https**', () {
      for (final ok in [
        'https://a.co',
        'https://github.com/x/y/releases/latest',
        '  https://a.co  ', // المسافاتُ تُقلَّم
      ]) {
        expect(isShareUrlValid(ok), isTrue, reason: 'رُدّ رابطٌ صالح: $ok');
      }
      for (final bad in [
        '',
        '   ',
        'http://a.co', // يُنذر في المتصفّح فيُقرأ احتيالاً
        'ftp://a.co',
        'a.co',
        'javascript:alert(1)',
        'https://', // بلا مضيف
        'https://a.co ثم كلام', // فراغٌ يقطع الرابط في واتساب
      ]) {
        expect(isShareUrlValid(bad), isFalse, reason: 'قُبل رابطٌ فاسد: $bad');
      }
    });
  });

  // ==========================================================================
  //  **رابطُ الدعوة: القاعدةُ أوّلاً ثمّ المخبوز**
  //
  //  أوّلُ رسالةٍ خرجت من هذا التطبيق خرجت **بلا سطر رابط** — لأنّ
  //  `app_settings.share_url` لم تُضبط بعد. فوصل الخبرُ إلى من لا يعرف من
  //  أين يأتي بالتطبيق، وضاعت الدعوة.
  // ==========================================================================

  group('اختيارُ الرابط', () {
    test('**قيمةُ القاعدة تعلو على المخبوز**', () {
      const fromDb = 'https://play.google.com/store/apps/details?id=x';
      expect(pickShareUrl(fromDb), fromDb,
          reason: 'صاحبُ المنصّة بدّله فلم يُؤخذ ببدله');
    });

    test('**والمخبوزُ يملأ فراغَها ولا يُترك النصُّ بلا باب**', () {
      // في الاختبار لا `--dart-define`، فالمخبوزُ فارغٌ — والمقصودُ أنّ
      // الفارغَ من القاعدة يقع على المخبوز أيّاً كان، لا على شيءٍ ثالث.
      expect(pickShareUrl(''), shareUrlFallback);
      expect(pickShareUrl('   '), shareUrlFallback);
      expect(pickShareUrl('http://a.co'), shareUrlFallback,
          reason: 'قيمةٌ فاسدةٌ في القاعدة تُتجاوَز لا تُستعمل');
    });
  });

  // ==========================================================================
  //  نصُّ الخدمة
  // ==========================================================================

  group('نصُّ الخدمة', () {
    test('يحمل ما يُسأل عنه: الاسم والمقدّم والمكان والسعر', () {
      final text = shareTextForService(_service(), url: _url);
      expect(text, contains('قاعة الأندلس'));
      expect(text, contains('قاعات الأندلس'));
      expect(text, contains('صنعاء'));
      expect(text, contains('250,000 ر.ي'));
      expect(text, contains('ليلة'));
      expect(text, contains(_url));
    });

    test('والمدى يُكتب مدىً لا مبلغاً واحداً', () {
      final text = shareTextForService(
        _service(price: 100000, priceTo: 300000),
        url: _url,
      );
      expect(text, contains('100,000 ر.ي – 300,000 ر.ي'),
          reason: 'ضاع الحدُّ الأعلى فبدا السعرُ أرخصَ ممّا هو');
    });

    test('**ولا سطرَ دعوةٍ مبتوراً إن لم يُضبط الرابط**', () {
      for (final bad in ['', 'http://a.co', 'ليس رابطاً']) {
        final text = shareTextForService(_service(), url: bad);
        expect(text, isNot(contains('حمّل')),
            reason: 'خرجت دعوةٌ بلا رابطٍ لها: «$bad»');
        expect(text, contains('قاعة الأندلس'),
            reason: 'ضاعت الخدمةُ مع الرابط — والاسمُ والسعرُ نافعان بلا رابط');
      }
    });

    test('**والوصفُ الطويل يُقصّ فلا يُطوى الرابطُ خلف «قراءة المزيد»**', () {
      final text = shareTextForService(
        _service(description: 'كلمة ' * 120),
        url: _url,
      );
      expect(text, contains(_url), reason: 'ضاع الرابطُ وهو المقصود');
      expect(text, contains('…'));
      // النصُّ كلُّه يبقى قريباً من حدٍّ يُقرأ في معاينة الرسالة.
      expect(text.length, lessThan(420), reason: 'رسالةٌ تُطوى فيضيع الرابط');
    });

    test('**ويُقصّ عند كلمةٍ لا في وسطها**', () {
      // **وطولُ الكلمة هنا مقصود.** أوّلُ صياغةٍ لهذا الاختبار استعملت كلمةً
      // من أربعة أحرفٍ وفراغ، وحدُّ القصّ مئةٌ وأربعون — وخمسةٌ تقسمها،
      // فوقع القطعُ على حافّة كلمةٍ تماماً وخرج القصُّ الصحيحُ والقصُّ
      // الأعمى سواءً. فبقي الاختبارُ أخضرَ حين كُسر الحارسُ عمداً، ولم
      // يكشفه إلّا ضابطٌ سالب.
      //
      // وستّةٌ لا تقسم مئةً وأربعين، فيقع الحدُّ في وسط كلمةٍ حتماً.
      final text = shareTextForService(
        _service(description: 'كلمات ' * 50),
        url: _url,
      );
      final cut = text.split('\n').firstWhere((l) => l.endsWith('…'));
      expect(cut, endsWith('كلمات…'),
          reason: 'قُطعت كلمةٌ في نصفها فخرج نصفُ كلمةٍ في رسالةٍ تُرسَل');
    });

    test('**وكلمةٌ واحدةٌ لا فراغَ فيها تُقصّ على كلّ حال**', () {
      // وإلّا لَخرج وصفٌ بطول مئتَي حرفٍ بلا قصٍّ لأنّه «كلمةٌ واحدة» —
      // وهو نصٌّ يلصقه صاحبُه من مكانٍ آخر، لا نادرٌ.
      final text = shareTextForService(
        _service(description: 'ب' * 400),
        url: _url,
      );
      expect(text, contains('…'), reason: 'لم يُقصّ أصلاً');
      expect(text, contains(_url), reason: 'ضاع الرابط');
      expect(text.length, lessThan(420));
    });

    test('وخدمةٌ بلا وصفٍ تخرج بلا سطرٍ فارغٍ معلّق', () {
      final text = shareTextForService(_service(description: '   '), url: _url);
      expect(text, isNot(contains('\n\n\n')));
      expect(text, contains('قاعة الأندلس'));
    });
  });

  // ==========================================================================
  //  نصُّ المقدّم
  // ==========================================================================

  group('نصُّ المقدّم', () {
    String make({num rating = 4.6, int reviews = 12, String about = 'قاعاتٌ وتنظيم.'}) =>
        shareTextForProvider(
          name: 'قاعات الأندلس',
          governorate: 'صنعاء',
          rating: rating,
          reviewsCount: reviews,
          about: about,
          url: _url,
        );

    test('يحمل الاسمَ والمكانَ والتقييم', () {
      final text = make();
      expect(text, contains('قاعات الأندلس'));
      expect(text, contains('صنعاء'));
      expect(text, contains('4.6'));
      expect(text, contains(_url));
    });

    test('**ولا نجومَ لمن لم يُقيَّم بعد**', () {
      // «٠٫٠ من ٥» تُقرأ رداءةً، وهو إنّما لم يُقيَّم — وهذا ظلمٌ يسافر في
      // رسالةٍ تُعاد إرسالُها.
      final text = make(rating: 0, reviews: 0);
      expect(text, isNot(contains('⭐')));
      expect(text, isNot(contains('0.0')));
      expect(text, contains('قاعات الأندلس'));
    });
  });

  // ==========================================================================
  //  **ما لا يخرج أبداً**
  // ==========================================================================

  test('**ولا يخرج في نصٍّ يُعاد إرسالُه رقمٌ ولا بريد**', () {
    // النصُّ يُبنى من الحقول العامّة وحدها. وهذا الاختبار يحرس ذلك من
    // إضافةٍ حسنةِ النيّة غداً: «ولمَ لا نضع رقمَه ليتّصلوا به مباشرةً؟» —
    // لأنّه لم يأذن، ولأنّ الرسالة تسافر إلى من لا يعرفه.
    final texts = [
      shareTextForService(_service(), url: _url),
      shareTextForProvider(
        name: 'قاعات الأندلس',
        governorate: 'صنعاء',
        rating: 4.6,
        reviewsCount: 12,
        about: 'قاعاتٌ وتنظيم.',
        url: _url,
      ),
      shareTextForApp(url: _url),
    ];
    for (final text in texts) {
      expect(text, isNot(matches(RegExp(r'\+?9677\d{7}'))), reason: 'رقمٌ يمنيّ');
      expect(text, isNot(matches(RegExp(r'7\d{8}'))), reason: 'رقمُ جوال');
      expect(text, isNot(contains('@')), reason: 'بريد');
    }
  });

  // ==========================================================================
  //  نصُّ التطبيق
  // ==========================================================================

  group('نصُّ التطبيق', () {
    test('يقول ما هو التطبيق لا اسمَه وحده', () {
      final text = shareTextForApp(url: _url);
      expect(text, contains('فرحتي'));
      expect(text, contains('زفاف'));
      expect(text, contains(_url));
    });

    test('**وبلا رابطٍ لا يُشارَك أصلاً**', () {
      // «فرحتي — كل خدمات زفافك في مكان واحد» بلا رابطٍ رسالةٌ لا يفعل
      // مستقبِلُها بها شيئاً.
      expect(shareTextForApp(url: ''), isEmpty);
      expect(shareTextForApp(url: 'http://a.co'), isEmpty);
    });
  });

  // ==========================================================================
  //  الأزرار
  // ==========================================================================

  group('الأزرار', () {
    setUp(resetShareUrlCache);
    tearDown(() {
      resetShareSink();
      resetShareUrlCache();
    });

    testWidgets('**زرُّ الخدمة يُرسل النصَّ المبنيَّ لا شيئاً آخر**',
        (tester) async {
      String? sent;
      shareSink = (text) async => sent = text;

      await tester.pumpWidget(_wrap(Scaffold(
        appBar: AppBar(actions: [ShareServiceButton(item: _service())]),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('share-button')));
      await tester.pumpAndSettle();

      expect(sent, isNotNull, reason: 'ضُغط الزرُّ فلم يقع شيء');
      expect(sent, contains('قاعة الأندلس'));
    });

    testWidgets('**وبندُ «شارك التطبيق» يغيب إن لم يُضبط الرابط**',
        (tester) async {
      // وفي النسخة التجريبيّة الرابطُ فارغٌ دائماً، فهذه هي الحالُ المقيسة.
      await tester.pumpWidget(_wrap(
        Scaffold(body: ListView(children: const [ShareAppTile()])),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('share-app')), findsNothing);
      // **ولا بطاقةَ فارغةٌ مكانَه:** إطارٌ فارغٌ في رأس الإعدادات أظهرُ
      // من البند نفسِه.
      expect(find.text('شارك التطبيق'), findsNothing);
    });
  });
}
