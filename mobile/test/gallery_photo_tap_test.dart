// صورُ تبويب «الصور» في الملفّ العامّ — تُفتح ملءَ الشاشة بالضغط.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «صورة خليها قابل للظغط». والشعارُ والغلافُ في هذه الشاشة نفسِها قابلان
// للضغط من قبلُ (`openPhoto`)، وصورُ المعرض وحدَها كانت ثابتةً — `ClipRRect`
// فوق `MediaThumb` بلا مستمعِ ضغطٍ إطلاقاً.
//
// ── ولا يُسأل الشكلُ عمّا يفعله ─────────────────────────────────────────────
//
// وجودُ `GestureDetector` في الشجرة لا يعني أنّ الضغطةَ تفتح شيئاً: قد
// يُوصَل بمسارٍ خطأ، أو بـ`onTap` فارغ. **فيُضغط ضغطاً حقيقيّاً** ويُسأل:
// أدُفعت `PhotoViewScreen` فعلاً، **وبرابط الصورة المضغوطة بعينها** لا
// بغيرها؟ الثانيةُ هي التي تنكسر بصمتٍ حين يُنسخ السطرُ ويبقى `items[0]`
// في شبكةٍ كلُّها صور.
//
// ── ولولا البديلُ لَما قيس شيء ─────────────────────────────────────────────
//
// `Api.mediaUrl` بلا خادمٍ يعود بـ`null` أبداً، و`openPhoto` لا تفتح عارضاً
// لرابطٍ فارغ. فلو قيس بلا `mediaUrlOverride` لَما فتح العارضُ في الحزمة
// أصلاً — ولمرّ الضابطُ السالبُ الذي يقطع الوصلةَ وهو لا يقيس شيئاً.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/provider_public.dart';
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

/// يفتح صفحةَ المزوّد العامّة ثمّ تبويبَ «الصور».
Future<void> _openGallery(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
  await _settle(tester);
  await tester.tap(find.text('الصور'));
  await _settle(tester);
}

/// صورتان في معرض `p1` — **ولا تُزاد في بيانات العرض لأجل الحزمة.**
/// وضعُ العرض يُرى على جوّالٍ ويُحكم به على المنتج، فلا يُغيَّر ما فيه لأجل
/// اختبار. وصورةٌ واحدةٌ (وهي كلُّ ما فيه) لا تكشف وصلةً مربوطةً بـ`items[0]`
/// ثابتاً — فتُزرع الثانيةُ هنا وتُردّ الحالُ بعدها.
final _seeded = <ServiceMedia>[
  const ServiceMedia(
    id: 'gm1',
    kind: MediaKind.image,
    path: 'p1/s1/hall.jpg',
    title: 'القاعة ليلة عرس',
    durationSeconds: 0,
    sizeBytes: 320000,
    sortOrder: 0,
  ),
  const ServiceMedia(
    id: 'gm2',
    kind: MediaKind.image,
    path: 'p1/s1/stage.jpg',
    title: 'الكوشة',
    durationSeconds: 0,
    sizeBytes: 280000,
    sortOrder: 1,
  ),
];

void main() {
  late Map<String, List<ServiceMedia>> saved;

  setUp(() {
    Api.mediaUrlOverride = (path) => 'https://example.invalid/$path';
    saved = Map.of(demoMedia);
    demoMedia = {...demoMedia, 's1': _seeded};
  });
  tearDown(() {
    Api.mediaUrlOverride = null;
    demoMedia = saved;
  });

  testWidgets('**الصورةُ تُفتح ملءَ الشاشة بالضغط**', (tester) async {
    await _openGallery(tester);

    expect(find.byKey(const ValueKey('gallery-photo-tap-0')), findsOneWidget,
        reason: 'لا مستمعَ ضغطٍ على صورة المعرض');
    expect(find.byType(PhotoViewScreen), findsNothing,
        reason: 'العارضُ مفتوحٌ قبل الضغط');

    await tester.tap(find.byKey(const ValueKey('gallery-photo-tap-0')));
    await _settle(tester);

    expect(find.byType(PhotoViewScreen), findsOneWidget,
        reason: 'الضغطةُ لم تفتح العارض');
    // التكبيرُ بالإصبعين هو معنى «ليس متحجراً» — وهو شرطُ الفائدة.
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('**وبرابط الصورة المضغوطة بعينها**', (tester) async {
    // شبكةٌ كلُّها صور، ويُضغط غيرُ الأولى: وصلةٌ مربوطةٌ بـ`items[0]`
    // ثابتاً تمرّ في العين وتفتح الصورةَ الخطأ.
    final images = demoProviderGallery('p1');
    expect(images.length, greaterThan(1),
        reason: 'صورةٌ واحدةٌ لا تكشف الوصلةَ الثابتة');

    await _openGallery(tester);
    await tester.tap(find.byKey(const ValueKey('gallery-photo-tap-1')));
    await _settle(tester);

    final viewer = tester.widget<PhotoViewScreen>(find.byType(PhotoViewScreen));
    expect(viewer.url, Api.mediaUrl(images[1].path),
        reason: 'فُتحت صورةٌ غيرُ المضغوطة');
  });

  testWidgets('**ولا زرَّ «تغيير» لمن لا يملكها**', (tester) async {
    // العارضُ نفسُه يُفتح لصاحب الملفّ وللعميل، وزرٌّ يُعرض لعميلٍ يُضغط
    // فيرتدّ عليه الطلبُ بخطأٍ لا يفهمه.
    await _openGallery(tester);
    await tester.tap(find.byKey(const ValueKey('gallery-photo-tap-0')));
    await _settle(tester);

    final viewer = tester.widget<PhotoViewScreen>(find.byType(PhotoViewScreen));
    expect(viewer.onEdit, isNull, reason: 'عُرض «تغيير» على من لا يملك الصورة');
    expect(find.byKey(const ValueKey('photo-edit')), findsNothing);
  });
}
