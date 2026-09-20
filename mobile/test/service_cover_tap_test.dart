// غلافُ صفحة الخدمة يُفتح بالضغط، ويُقلَّب فيه بين الصور كلِّها.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «صورة غير قابلة للضغط هنا» — وكان غلافُ `service_detail.dart` هو الباقيَ
// وحدَه ساكناً: صورُ معرض المزوّد وشعارُه وغلافُه تُفتح منذ جولةٍ سابقة.
// واختار (ج) من ثلاث: عارضٌ يُقلَّب فيه بين الصور كلِّها ملءَ الشاشة.
//
// ── ولا يُسأل الشكلُ عمّا يفعله ─────────────────────────────────────────────
//
// وجودُ `GestureDetector` في الشجرة لا يعني أنّ الضغطةَ تفتح شيئاً. **فيُضغط
// ضغطاً حقيقيّاً** ويُسأل: أفُتح العارض؟ وبأيّ صورةٍ بدأ؟ **والثانيةُ هي
// التي تنكسر بصمت**: عارضٌ يبدأ من الأولى أبداً يُلزم صاحبَه أن يقلّب
// ليعود إلى حيث كان، ولا يظهر ذلك إلّا لمن قلّب قبل أن يضغط.
//
// ── ولولا البديلُ لَما قيس شيء ─────────────────────────────────────────────
//
// `Api.mediaUrl` بلا خادمٍ تعود بـ`null`، و`openGallery` لا تفتح على لا شيء.
// فبلا `mediaUrlOverride` لَما فُتح عارضٌ في الحزمة أصلاً — ولمرّ الضابطُ
// السالبُ الذي يقطع الوصلةَ وهو لا يقيس شيئاً.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/service_detail.dart';
import 'package:aras/src/ui/photo_view.dart';

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

ServiceMedia _image(String id, String path) => ServiceMedia(
      id: id,
      kind: MediaKind.image,
      path: path,
      title: '',
      durationSeconds: 0,
      sizeBytes: 100000,
      sortOrder: 0,
    );

/// ثلاثُ صورٍ لخدمة `s1` — **ولا تُزاد في بيانات العرض لأجل الحزمة**؛
/// وضعُ العرض يُرى على جوّالٍ ويُحكم به على المنتج. تُزرع هنا وتُردّ بعده.
final _three = [
  _image('m1', 'p1/s1/one.jpg'),
  _image('m2', 'p1/s1/two.jpg'),
  _image('m3', 'p1/s1/three.jpg'),
];

Future<void> _open(WidgetTester tester, {required int images}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  demoMedia = {...demoMedia, 's1': _three.take(images).toList()};
  await tester.pumpWidget(_wrap(const ServiceDetailScreen(
    serviceId: 's1',
    coverPath: 'p1/s1/one.jpg',
  )));
  await _settle(tester);
}

void main() {
  late Map<String, List<ServiceMedia>> saved;

  setUp(() {
    Api.mediaUrlOverride = (path) => 'https://example.invalid/$path';
    saved = Map.of(demoMedia);
  });
  tearDown(() {
    Api.mediaUrlOverride = null;
    demoMedia = saved;
  });

  testWidgets('**الغلافُ الواحدُ يُفتح بالضغط**', (tester) async {
    await _open(tester, images: 1);

    expect(find.byType(PhotoGalleryScreen), findsNothing,
        reason: 'العارضُ مفتوحٌ قبل الضغط');
    await tester.tap(find.byKey(const ValueKey('service-cover-tap')));
    await _settle(tester);

    expect(find.byType(PhotoGalleryScreen), findsOneWidget,
        reason: 'الضغطةُ لم تفتح العارض');
    // ولا عدّادَ لصورةٍ واحدة: «١ / ١» رقمٌ لا معنى له.
    expect(find.text('1 / 1'), findsNothing);
  });

  testWidgets('**والمعرضُ المقلَّبُ يُفتح كذلك**', (tester) async {
    await _open(tester, images: 3);

    await tester.tap(find.byKey(const ValueKey('service-cover-tap-0')));
    await _settle(tester);

    expect(find.byType(PhotoGalleryScreen), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget, reason: 'لا عدّادَ يقول أين هو');
  });

  testWidgets('**ويُفتح على المعروضة الآن لا على أوّلها**', (tester) async {
    // **وهذه هي التي تنكسر بصمت**: عارضٌ يبدأ من الأولى أبداً يعمل ويبدو
    // سليماً، ولا يُرى نقصُه إلّا لمن قلّب قبل أن يضغط.
    await _open(tester, images: 3);

    // **ويُسحب إلى اليمين لا إلى اليسار.** المقلَّبُ يتبع اتّجاهَ اللغة،
    // فالتاليةُ في العربيّة تأتي من اليسار — والسحبُ إليها موجب.
    await tester.drag(find.byType(PageView).first, const Offset(400, 0));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('service-cover-tap-1')));
    await _settle(tester);

    expect(find.text('2 / 3'), findsOneWidget,
        reason: 'العارضُ بدأ من أوّل الصور لا من المعروضة');
  });

  testWidgets('**ويُقلَّب داخلَه بين الصور كلِّها**', (tester) async {
    // وهو الفرقُ بين (ج) و(أ): لا يُرجَع ليُقلَّب ويُضغط من جديد.
    await _open(tester, images: 3);
    await tester.tap(find.byKey(const ValueKey('service-cover-tap-0')));
    await _settle(tester);

    await tester.drag(
        find.byKey(const ValueKey('photo-gallery-pages')), const Offset(400, 0));
    await _settle(tester);
    expect(find.text('2 / 3'), findsOneWidget, reason: 'لا يُقلَّب داخلَ العارض');

    await tester.drag(
        find.byKey(const ValueKey('photo-gallery-pages')), const Offset(400, 0));
    await _settle(tester);
    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('**ولا يُفتح على لا شيء**', (tester) async {
    // شاشةٌ سوداءُ فارغةٌ لا تقول شيئاً — ومن لا صورةَ له لا يُفتح له عارض.
    //
    // **وتُنادى الدالّةُ نفسُها بسياقٍ حقيقيّ** لا يُفحص شرطُها بيدٍ: شرطٌ
    // يُعاد كتابتُه في الاختبار يقيس الاختبارَ لا الشيفرة.
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => openGallery(context, urls: const ['', '']),
            child: const Text('افتح'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('افتح'));
    await _settle(tester);

    expect(find.byType(PhotoGalleryScreen), findsNothing,
        reason: 'فُتح عارضٌ على روابطَ فارغة');
  });
}
