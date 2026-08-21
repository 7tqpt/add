// وسائط الخدمة: شاشة المزوّد، وما يراه العميل.
//
// ولا مشغّلَ حيٍّ في هذه الاختبارات: `video_player` شيفرةٌ أصلية لا وجود لها
// في بيئة الاختبار. فالمقصود هنا ما يُبنى قبل التشغيل وما يُعرض حين لا رابط —
// وهي الحال التي يقع فيها المستخدم حين تسقط شبكته، لا حالٌ مصطنعة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/service_detail.dart';
import 'package:aras/src/screens/service_media.dart';
import 'package:aras/src/screens/services.dart';
import 'package:aras/src/ui/media.dart';

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

/// انتظارٌ يشمل ما لا يرسم إطاراً.
///
/// `pumpAndSettle` تتقدّم بالزمن ما دامت هناك إطاراتٌ مجدولة، وتقف حين لا
/// تكون. وكتلةُ الوسائط لا ترسم شيئاً وهي تُحمَّل — لا دائرةَ تدور ولا هيكلاً
/// رمادياً — فلا إطارَ يُجدول، فتعود `pumpAndSettle` فوراً ولم يمضِ من الزمن
/// شيء، ويبقى نداؤها معلّقاً إلى نهاية الاختبار. فالدفعةُ الصريحة هنا هي ما
/// يمرّر الزمن.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, {double height = 2600}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _providerSession() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

void main() {
  setUp(() {
    // كل اختبارٍ يبدأ من الحال نفسها: الإضافة والحذف يكتبان في خرائط العرض،
    // فبلا إعادةٍ يرث الاختبارُ ما رفعه سابقُه ويقع الحدُّ في غير موضعه.
    demoMedia = {
      's1': const [
        ServiceMedia(
          id: 'm1',
          kind: MediaKind.image,
          path: 'p1/s1/hall.jpg',
          title: '',
          durationSeconds: 0,
          sizeBytes: 320000,
          sortOrder: 0,
        ),
        ServiceMedia(
          id: 'm2',
          kind: MediaKind.video,
          path: 'p1/s1/tour.mp4',
          title: '',
          durationSeconds: 48,
          sizeBytes: 18000000,
          sortOrder: 0,
        ),
      ],
    };
  });

  group('شاشة المزوّد', () {
    testWidgets('ثلاثة أبوابٍ: صورٌ وفيديو وصوت', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _wrap(const ServiceMediaScreen(
          providerId: 'p1',
          serviceId: 's1',
          serviceTitle: 'قاعة التاج',
        )),
      );
      await _settle(tester);

      expect(find.text('الصور'), findsOneWidget);
      expect(find.text('مقطع فيديو'), findsOneWidget);
      expect(find.text('مقطع صوتي'), findsOneWidget);
    });

    testWidgets('العدّاد يقول كم بقي من الثماني', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _wrap(const ServiceMediaScreen(
          providerId: 'p1',
          serviceId: 's1',
          serviceTitle: 'قاعة التاج',
        )),
      );
      await _settle(tester);
      expect(find.text('1/8'), findsOneWidget);
    });

    testWidgets('المرفوع يظهر بمدّته وحجمه لا بمسارٍ خام', (tester) async {
      // المسار `p1/s1/tour.mp4` لا يعني شيئاً لصاحب القاعة. وما يعنيه:
      // كم طال المقطع وكم يزن — فبهما يحكم أيبقيه أم يستبدله.
      _phone(tester);
      await tester.pumpWidget(
        _wrap(const ServiceMediaScreen(
          providerId: 'p1',
          serviceId: 's1',
          serviceTitle: 'قاعة التاج',
        )),
      );
      await _settle(tester);

      expect(find.text(formatSeconds(48)), findsOneWidget);
      expect(find.text(formatBytes(18000000)), findsOneWidget);
      expect(find.textContaining('tour.mp4'), findsNothing);
    });

    testWidgets('وزرُّ الإضافة يغيب عند بلوغ الحدّ', (tester) async {
      // البابُ المفتوح على ما لا يُقبل أسوأ من بابٍ مغلق: من ضغط ثمّ رُدَّ من
      // الخادم ظنّ العطبَ في التطبيق.
      demoMedia = {
        's1': [
          for (var i = 0; i < Api.mediaMaxImages; i++)
            ServiceMedia(
              id: 'm$i',
              kind: MediaKind.image,
              path: 'p1/s1/$i.jpg',
              title: '',
              durationSeconds: 0,
              sizeBytes: 1000,
              sortOrder: i,
            ),
        ],
      };
      _phone(tester);
      await tester.pumpWidget(
        _wrap(const ServiceMediaScreen(
          providerId: 'p1',
          serviceId: 's1',
          serviceTitle: 'قاعة التاج',
        )),
      );
      await _settle(tester);

      expect(find.text('8/8'), findsOneWidget);
      expect(find.text('أضف صورة'), findsNothing);
      expect(find.text('بلغتَ الحدّ. احذف صورةً لتضيف غيرها.'), findsOneWidget);
    });

    testWidgets('وخدمةٌ بلا وسائط تعرض الأبواب الثلاثة فارغة لا شاشةً خاوية', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _wrap(const ServiceMediaScreen(
          providerId: 'p9',
          serviceId: 's9',
          serviceTitle: 'خدمةٌ جديدة',
        )),
      );
      await _settle(tester);

      expect(find.text('0/8'), findsOneWidget);
      expect(find.text('أضف صورة'), findsOneWidget);
      expect(find.text('أضف مقطع فيديو'), findsOneWidget);
      expect(find.text('أضف مقطعاً صوتياً'), findsOneWidget);
    });
  });

  group('شاشة العميل', () {
    testWidgets('الوسائط فوق السعر لا تحته', (tester) async {
      // من فتح الخدمة يريد أن يرى ما يشتريه قبل أن يقرأ عنه.
      _phone(tester);
      await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
      await _settle(tester);

      final media = tester.getTopLeft(find.byType(MediaThumb).first).dy;
      final price = tester.getTopLeft(find.text('السعر').first).dy;
      expect(media, lessThan(price));
    });

    testWidgets('ومقطع الفيديو له إطارُه', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
      await _settle(tester);
      expect(find.byType(VideoBox), findsOneWidget);
      expect(find.byType(AudioBar), findsNothing);
    });

    testWidgets('والصوت شريطٌ لا إطارٌ أسود فارغ', (tester) async {
      demoMedia = {
        's1': const [
          ServiceMedia(
            id: 'm3',
            kind: MediaKind.audio,
            path: 'p1/s1/sample.m4a',
            title: 'مقطع من حفل',
            durationSeconds: 55,
            sizeBytes: 900000,
            sortOrder: 0,
          ),
        ],
      };
      _phone(tester);
      await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
      await _settle(tester);

      expect(find.byType(AudioBar), findsOneWidget);
      expect(find.byType(VideoBox), findsNothing);
    });

    testWidgets('وخدمةٌ بلا وسائط لا تعرض فراغاً ولا رسالة نقص', (tester) async {
      // «لا صور» تقول للعميل إن شيئاً ينقص وهو لا يملك إصلاحه، فتُقرأ عيباً
      // في المنصّة لا في الخدمة.
      demoMedia = {};
      _phone(tester);
      await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
      await _settle(tester);

      expect(find.byType(MediaThumb), findsNothing);
      expect(find.byType(VideoBox), findsNothing);
      expect(find.byType(AudioBar), findsNothing);
      expect(find.text('السعر').first, findsOneWidget);
    });

    testWidgets('والمشغّل بلا رابطٍ يقول ذلك ولا يعلّق دائرةً تدور', (tester) async {
      // وضعُ العرض بلا سلّة، وشبكةُ المستخدم قد تسقط — والحالان واحدة.
      _phone(tester);
      await tester.pumpWidget(_wrap(const Scaffold(body: AudioBar(url: null, seconds: 30))));
      await _settle(tester);
      expect(find.text('تعذّر تشغيل المقطع'), findsOneWidget);
    });
  });

  group('ربطُ الشاشتين', () {
    testWidgets('بطاقة الخدمة عند المزوّد تفتح باب الوسائط', (tester) async {
      // خدمةٌ واحدة في وضع العرض: القائمة تبدأ فارغة، وشاشةٌ فارغة لا بطاقة
      // فيها ولا زرّ — فيمرّ الاختبار على لا شيء.
      demoMyServices = [
        const MyService(
          id: 's1',
          title: 'قاعة التاج — باقة شاملة',
          description: '',
          price: 850000,
          priceTo: null,
          unit: 'للحجز',
          depositPercent: 30,
          categoryId: 'c1',
          isActive: true,
        ),
      ];
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _providerSession())));
      await _settle(tester);

      expect(find.text('الصور والمقاطع'), findsWidgets);
      await tester.tap(find.text('الصور والمقاطع').first);
      await _settle(tester);
      expect(find.byType(ServiceMediaScreen), findsOneWidget);
    });
  });
}
