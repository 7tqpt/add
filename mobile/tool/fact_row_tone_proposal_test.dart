// **مقترحٌ لا تنفيذ.** لماذا تبدو أيقونتا «رقم الجوال» و«البريد» مخالفتين
// لأيقونتَي «الاسم الكامل» و«المحافظة» — واللونُ واحدٌ إلى البايت.
//
//   SHOTS=<مجلّد> flutter test tool/fact_row_tone_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما قيس في اللقطة المشحونة ──────────────────────────────────────────────
//
// قال صاحبُ المنصّة: «بالله عليك هذا لون أيقونات نفس الاسم كامل؟ لونه غير».
// فقيست بكسلاتُ لقطة `art-profile.png`:
//
//   الاسم الكامل  #524344 — حبرٌ ١٦٫٤٪
//   المحافظة      #524344 — حبرٌ ١٨٫٤٪
//   رقم الجوال    #524344 — حبرٌ ١٥٫١٪
//   البريد        #524344 — حبرٌ ٢٧٫١٪
//
// **فاللونُ واحد، والفرقُ في شيئين آخرين:**
//
//   ١) **الأرضيّة.** الحقلان على `surface` أبيض، والسطران على `surface2`
//      ورديّ — واللونُ الواحدُ يُقرأ أغمقَ على الورديّ.
//
//   ٢) **ورسمُ الظرف أثقل.** يملأ ٢٧٪ من مربّعه وأخواتُه ١٥–١٨٪، فيبدو
//      أعرضَ حبراً ولو لم يتغيّر لونُه.
//
// ── وما هو حقيقيٌّ هنا وما هو مرسوم ────────────────────────────────────────
//
// **بطاقةُ «بياناتي» حقيقيّة** في كلّ لقطة — `AppCard` وحقولُ التطبيق
// بثيمته، فأيقونتا الاسم والمحافظة هما المشحونتان بلونهما الحقيقيّ.
//
// **والسطران مرسومان ويُقال:** `_FactRow` خاصٌّ بـ`edit_profile.dart` ولا
// مدخلَ لأرضيّته، فلا يُصوَّر ما لم يُكتب. والمرسومُ نسخةٌ حرفيّةٌ من بنائه.
//
// **ولا يُنقل اللونُ بالعين:** يُقرأ لونُ أيقونة الحقل من شجرة العناصر
// ويُمرَّر إلى المرسوم، ويُتحقَّق من تساويهما قبل اللقطة.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
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

Color? _colorOf(WidgetTester tester, IconData icon) {
  final element = tester.element(find.byIcon(icon).first);
  return (element.widget as Icon).color ?? IconTheme.of(element).color;
}

Widget _wrap(Widget child) => MaterialApp(
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
            appBar: AppBar(title: Text(tr('تعديل بياناتي'))),
            body: ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [child],
            ),
          ),
        ),
      ),
    );

/// حقلا البطاقة — **حقيقيّان**، وبأيقونتيهما يُقاس.
List<Widget> _fields() => [
      SectionTitle(tr('بياناتي')),
      const SizedBox(height: Space.lg),
      TextField(
        controller: TextEditingController(text: 'مستخدم تجريبي'),
        decoration: InputDecoration(
          labelText: tr('الاسم الكامل'),
          prefixIcon: const Icon(Icons.person_outline, size: 20),
        ),
      ),
      const SizedBox(height: Space.md),
      DropdownButtonFormField<String>(
        initialValue: 'sanaa',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: tr('المحافظة'),
          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
        ),
        items: [DropdownMenuItem(value: 'sanaa', child: Text(tr('صنعاء')))],
        onChanged: (_) {},
      ),
    ];

/// السطرُ المرسوم — أرضيّتُه ولونُه وأيقونتُه تُمرَّر.
Widget _fact({
  required IconData icon,
  required String label,
  required String value,
  required String action,
  required bool strong,
  required Color? iconColor,
  required Color background,
  required BoxBorder? border,
}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        border: border,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Muted(label, size: 11),
                const SizedBox(height: 2),
                Text(
                  value,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ],
            ),
          ),
          if (strong)
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(action),
            )
          else
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(action),
            ),
        ],
      ),
    );

/// ما يفترق بين المقترحات.
enum _Variant {
  /// اليومَ: أرضيّةٌ ورديّة، وظرفٌ ثقيلُ الرسم.
  today,

  /// (أ) أرضيّةُ السطرين بيضاءُ كالبطاقة، بخيطٍ يحدّها.
  white,

  /// (ب) السطران داخل بطاقة «بياناتي» نفسِها — أرضيّةٌ واحدةٌ للأربع.
  inside,

  /// (ج) الأرضيّةُ الورديّةُ باقيةٌ، وأيقونةُ بريدٍ أخفُّ رسماً.
  lightMail,
}

Widget _page({required _Variant variant, required Color? iconColor}) {
  final onWhite = variant == _Variant.white || variant == _Variant.inside;
  final rows = [
    _fact(
      icon: Icons.phone_outlined,
      label: tr('رقم الجوال'),
      // **ولا رقمَ إنسانٍ في الشجرة** — نسقٌ لا صاحبَ له.
      value: '+967 7XX XXX XXX',
      action: tr('تعديل'),
      strong: true,
      iconColor: iconColor,
      background: onWhite ? AppColors.surface : AppColors.surface2,
      border: variant == _Variant.white
          ? Border.all(color: AppColors.hairline)
          : null,
    ),
    const SizedBox(height: Space.sm),
    _fact(
      // **والظرفُ أثقلُ رسماً من أخواته** — ٢٧٪ حبراً مقابل ١٥–١٨٪.
      // و`alternate_email` أقربُ إليهنّ وزناً.
      icon: variant == _Variant.lightMail
          ? Icons.alternate_email
          : Icons.mail_outline,
      label: tr('البريد الإلكتروني'),
      value: 'name@example.com',
      action: tr('لماذا؟'),
      strong: false,
      iconColor: iconColor,
      background: onWhite ? AppColors.surface : AppColors.surface2,
      border: variant == _Variant.white
          ? Border.all(color: AppColors.hairline)
          : null,
    ),
  ];

  if (variant == _Variant.inside) {
    // أرضيّةٌ واحدةٌ للأربع: السطران داخل البطاقة، ويفصلهما خيط.
    return AppCard(
      children: [
        ..._fields(),
        const SizedBox(height: Space.lg),
        const Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: Space.md),
        ...rows,
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppCard(children: _fields()),
      const SizedBox(height: Space.md),
      ...rows,
    ],
  );
}

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  for (final (name, variant) in const [
    ('today', _Variant.today),
    ('a', _Variant.white),
    ('b', _Variant.inside),
    ('c', _Variant.lightMail),
  ]) {
    testWidgets('نبرةُ السطرين — $name', (tester) async {
      phone(tester);

      // تُبنى مرّةً ليُقرأ لونُ الحقل الحقيقيّ، ثمّ يُعاد البناءُ به.
      await tester.pumpWidget(
          _wrap(_page(variant: variant, iconColor: AppColors.muted)));
      await settle(tester);
      final field = _colorOf(tester, Icons.person_outline);

      await tester
          .pumpWidget(_wrap(_page(variant: variant, iconColor: field)));
      await settle(tester);

      // **والتساوي يُثبت قبل اللقطة** — فالسؤالُ عن الأرضيّة والرسم، لا
      // عن لونٍ ما زال مختلفاً.
      expect(_colorOf(tester, Icons.phone_outlined), field,
          reason: 'المرسومُ لم يساوِ المشحون — فاللقطةُ تسأل عن غير موضوعها');
      expect(find.text('بياناتي'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _shoot(tester, '$out/tone-$name.png');
    });
  }
}
