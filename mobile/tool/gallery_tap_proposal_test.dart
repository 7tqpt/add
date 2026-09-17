// **مقترحٌ لا تنفيذ.** تبويبُ «الصور» في الملفّ العامّ لمقدّم الخدمة —
// صورُه اليوم ثابتة، والمقترحُ أن تُفتح ملءَ الشاشة بالضغط، كما الشعارُ
// والغلافُ من قبلُ. ومعها لقطةٌ لشاشة «تفاصيل الخدمة» كما هي اليوم — بلا
// اقتراحٍ لها، بطلبٍ منفصل.
//
//   SHOTS=<مجلّد> flutter test tool/gallery_tap_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «صورة خليها قابل للظغط وصور تفاصيل الخدمة» — على شاشةِ ملفِّ المزوّد
// العامّ (تبويبُ «الصور» مفتوحاً في لقطته). وشعارُ المزوّد وغلافُه في هذه
// الشاشة نفسِها **قابلان للضغط من قبلُ** (`openPhoto` في
// `lib/src/ui/photo_view.dart`، مستعملةٌ في `provider_public.dart` أسطر
// ٢٦٧-٢٨٧) — والصورُ في شبكة «الصور» (`_Gallery`، أسطر ٧١٦-٧٥٣) وحدَها لم
// تُوصَل بها؛ `ClipRRect` فوق `MediaThumb` بلا `GestureDetector` إطلاقاً.
// فالمقترحُ: الوصلةُ نفسُها — لا عارضٌ جديد.
//
// ── وما فيه حقيقيّ ────────────────────────────────────────────────────────
//
// **`PhotoViewScreen` هي الودجتُ نفسُه الذي سيُفتح** — بثيمة التطبيق
// وخلفيّته السوداء المقصودة وتكبيره بالإصبعين (`InteractiveViewer`) وزرَّ
// «تغيير» الساقط عن العميل (`onEdit: null`، كما تُفتح بالضبط من الصفحة
// العامّة اليوم للشعار والغلاف). **ولا صورةَ حقيقيّةً تظهر فيه هنا**:
// `Image.network` بلا خادمٍ في `flutter test` يدخل شجرة الودجتات بصفرِ
// بكسلٍ مرسوم — وهو محدودٌ ذُكر صراحةً من قبلُ في هذا المستودع (انظر
// `conversations_avatar_shot_test.dart` القديم) — فتظهر رسالةُ «تعذّر
// تحميل الصورة» الحقيقيّةُ التي يراها هو نفسُه اليومَ لو سقطت الشبكة؛ وهذا
// مرسومٌ لا مصوَّر.
//
// **و`ServiceDetailScreen` الحقيقيّةُ بخدمةٍ تجريبيّة** (`demoServices`
// الأولى، `s1`) — نصُّها وسعرُها ووصفُها حقيقيّون، وصورُها كالصورة أعلاه
// بلا خادم.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/service_detail.dart';
import 'package:aras/src/ui/photo_view.dart';

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(File(p).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _load('IBMPlexSansArabic', [
    for (final w in ['400', '500', '600', '700'])
      'assets/fonts/IBMPlexSansArabic-$w.ttf',
  ]);
  await _load('NotoNaskhArabic', ['assets/fonts/NotoNaskhArabic-Regular.ttf']);
  final icons = File(
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await _load('MaterialIcons', [icons.path]);
}

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  final image = await boundary.toImage(pixelRatio: 3.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _wrap(Widget child) => RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('المقترح — الصورة تُفتح ملءَ الشاشة', (tester) async {
    tester.view.physicalSize = const Size(1080, 1900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // **نفسُ `PhotoViewScreen` التي تفتحها `openPhoto` اليوم للشعار
    // والغلاف** — بلا `onEdit`، كما تُفتح من الصفحة العامّة بحرفها.
    await tester.pumpWidget(_wrap(
      const PhotoViewScreen(url: 'demo/hall-1.jpg'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(InteractiveViewer), findsOneWidget,
        reason: 'التكبيرُ بالإصبعين غاب — فلا فائدةَ من العارض');
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/gallery-photo-viewer.png');
  });

  testWidgets('تفاصيلُ الخدمة — كما هي اليوم', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('قاعة التاج — باقة شاملة'), findsWidgets,
        reason: 'الخدمةُ التجريبيّةُ لم تصل — فلا شيءَ في اللقطة');
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/service-detail-today.png');
  });
}
