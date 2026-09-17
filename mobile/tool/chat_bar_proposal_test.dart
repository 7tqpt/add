// **مقترحٌ لا تنفيذ.** شريطُ المحادثة العلويّ: صورةُ الطرف الآخر، وضغطةٌ
// تنقل إلى ملفّه.
//
//   SHOTS=<مجلّد> flutter test tool/chat_bar_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أحسّ الشريط العلوي يبغي تحط صورة وتخليه قابل للضغط وانتقل إلى الملف
// الشخصي».
//
// ── وما هو حقيقيٌّ هنا وما هو مرسوم ────────────────────────────────────────
//
// **الشريطُ حقيقيّ:** `AppBar` بثيمة التطبيق (`buildTheme`)، وسطرُ الحضور
// `PresenceLine` المشحونُ نفسُه، والخطوطُ محمّلة.
//
// **والقرصُ مرسوم**: لا شبكةَ في `flutter test` فلا تُجلب صورةُ أحد — فرُسم
// قرصٌ بحرف الاسم كما يرسمه التطبيقُ حين لا صورةَ للطرف الآخر. وهي الحالُ
// الغالبةُ أصلاً.
//
// **والفراغُ تحت الشريط فارغٌ عمداً**: السؤالُ عن الشريط وحدَه.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/kit.dart';

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

Future<void> _shoot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

const _name = 'قاعة اللؤلؤة للأفراح';
final _seen = DateTime.now();

/// القرصُ المرسوم — حرفُ الاسم، كما يرسمه التطبيقُ حين لا صورة.
Widget _disc(double size) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: Text(
        _name.characters.first,
        style: TextStyle(
          fontSize: size * 0.44,
          fontWeight: FontWeight.w700,
          color: AppColors.accentInk,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

Widget _titleText() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis),
        PresenceLine(lastSeen: _seen, size: 11.5),
      ],
    );

/// ما يفترق بين المقترحات.
enum _Variant {
  /// اليومَ: اسمٌ وحضورٌ، ولا صورةَ ولا ضغطة.
  today,

  /// (أ) قرصٌ ٣٦ يمينَ الاسم، والشريطُ كلُّه يُضغط.
  disc,

  /// (ب) مثلُها ومعها سهمٌ صغيرٌ يقول إنّها تُضغط.
  discChevron,
}

PreferredSizeWidget _bar(_Variant variant) {
  // **وسهمُ الرجوع يُذكر صراحة.** لا شيءَ يُرجَع إليه في الراسم، فلا يرسمه
  // `AppBar` من نفسه — ولقطةٌ بلا سهمٍ تُري شريطاً غيرَ الذي يراه.
  const back = BackButton();
  if (variant == _Variant.today) {
    return AppBar(leading: back, title: _titleText());
  }

  final row = Row(
    children: [
      _disc(36),
      const SizedBox(width: Space.md),
      Expanded(child: _titleText()),
      if (variant == _Variant.discChevron)
        const Icon(Icons.chevron_left, size: 22, color: AppColors.muted),
    ],
  );

  return AppBar(
    leading: back,
    titleSpacing: Space.sm,
    title: InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: row,
      ),
    ),
  );
}

Widget _wrap(_Variant variant) => MaterialApp(
      debugShowCheckedModeBanner: false,
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
        child: RepaintBoundary(
          key: const ValueKey('shot'),
          child: Scaffold(
            appBar: _bar(variant),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  for (final (file, variant) in const [
    ('today', _Variant.today),
    ('a', _Variant.disc),
    ('b', _Variant.discChevron),
  ]) {
    testWidgets('شريطُ المحادثة — $file', (tester) async {
      // نافذةٌ قصيرة: المصوَّرُ الشريطُ وحدَه.
      tester.view.physicalSize = const Size(1080, 420);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(variant));
      await tester.pumpAndSettle();

      expect(find.text(_name), findsOneWidget,
          reason: 'لم يُبنَ الشريطُ — فلا شيءَ في اللقطة');
      expect(tester.takeException(), isNull);

      await _shoot(tester, '$out/chatbar-$file.png');
    });
  }
}
