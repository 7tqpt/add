// **مقترحٌ لا تنفيذ.** رأسُ «الملف الشخصي» بعد اختيار الارتفاع: الفراغُ
// تحت الغلاف، ولونُ أيقونتَي «رقم الجوال» و«البريد الإلكتروني».
//
//   SHOTS=<مجلّد> flutter test tool/profile_head_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما اختير وما بقي ───────────────────────────────────────────────────────
//
// اختار صاحبُ المنصّة الغلافَ الطويل — **٢٣٠**، وهو ثابتٌ في كلّ لقطةٍ هنا
// فلا يُسأل عنه ثانية. وبقي سؤالان قالهما:
//
//   ١) «أريدها ما يكون فراغ بين بياناتي والغلاف» — واليومَ بينهما
//      `Space.xl` أي ٢٤.
//
//   ٢) «خلّه لي أيقونة منسّقة نفس لون الاسم والمحافظة» — ثمّ: «اللي البريد
//      ورقم الجوال، جيب صورة قبل تنفيذ». واليومَ أيقونتا السطرين مكتوبتان
//      `AppColors.muted` بقياس ١٩، وأيقونتا الحقلين تأخذان لونَهما من
//      الثيمة بقياس ٢٠.
//
// ── وما هو حقيقيٌّ هنا وما هو مرسوم ────────────────────────────────────────
//
// **بطاقةُ «بياناتي» حقيقيّة:** `AppCard` و`SectionTitle` و`TextField`
// و`DropdownButtonFormField` بثيمة التطبيق — فأيقونتا الاسم والمحافظة
// **هما المشحونتان بلونهما الحقيقيّ**، وبهما يُقاس.
//
// **والغلافُ والسطرانِ مرسومان ويُقال:** ارتفاعُ الغلاف ثابتٌ في
// `_ProfileArt`، و`_FactRow` خاصٌّ بـ`edit_profile.dart` ولا مدخلَ للونه —
// فلا يُصوَّر ما لم يُكتب. والمرسومُ نسخةٌ حرفيّةٌ من بنائهما: التدرّجُ
// `accentLift → accentDeep`، ونصفُ القطر `Space.lg`، والقرصُ ١٠٨ بطوقٍ ٣،
// و`surface2` ونصفُ قطرٍ ١٤ وحشوةٌ ١٤/١٠ و`Muted` بقياس ١١ والقيمةُ ١٣
// بوزن ٦٠٠.
//
// **ولا يُنقل اللونُ بالعين:** يُقرأ لونُ أيقونة الحقل الحقيقيّة من شجرة
// العناصر، ويُمرَّر إلى المرسوم، ويُتحقَّق من تساويهما قبل اللقطة. فلو
// تبدّلت الثيمةُ يوماً تبدّل المقترحُ معها ولم يكذب.
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

/// الارتفاعُ المختار. ثابتٌ هنا — السؤالُ صار عمّا تحته.
const _cover = 230.0;
const _disc = 108.0;

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

/// لونُ أيقونةٍ كما تُرسم فعلاً — من الشجرة لا من الظنّ.
Color? _iconColor(WidgetTester tester, IconData icon) {
  final element = tester.element(find.byIcon(icon).first);
  final widget = element.widget as Icon;
  return widget.color ?? IconTheme.of(element).color;
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

/// الغلافُ والقرصُ — مرسومان بثوابت الشيفرة.
Widget _art() => SizedBox(
      height: _cover + _disc / 2 + 6,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            height: _cover,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Space.lg),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [AppColors.accentLift, AppColors.accentDeep],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
          ),
          Container(
            width: _disc,
            height: _disc,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Text(
              'م',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: AppColors.accentInk,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ),
        ],
      ),
    );

/// السطرُ المرسوم — نسخةٌ حرفيّةٌ من `_FactRow`، واللونُ والقياسُ يُمرَّران.
Widget _fact({
  required IconData icon,
  required String label,
  required String value,
  required String action,
  required bool strong,
  required Color? iconColor,
  required double iconSize,
}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: iconSize, color: iconColor),
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

Widget _page({
  required double gap,
  required Color? iconColor,
  required double iconSize,
}) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _art(),
        SizedBox(height: gap),
        // **حقيقيّة** — وبأيقونتيها يُقاس اللون.
        AppCard(
          children: [
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
              items: [
                DropdownMenuItem(value: 'sanaa', child: Text(tr('صنعاء'))),
              ],
              onChanged: (_) {},
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        // **مرسومان.**
        _fact(
          icon: Icons.phone_outlined,
          label: tr('رقم الجوال'),
          // **ولا رقمَ إنسانٍ في الشجرة** — نسقٌ لا صاحبَ له.
          value: '+967 7XX XXX XXX',
          action: tr('تعديل'),
          strong: true,
          iconColor: iconColor,
          iconSize: iconSize,
        ),
        const SizedBox(height: Space.sm),
        _fact(
          icon: Icons.mail_outline,
          label: tr('البريد الإلكتروني'),
          value: 'name@example.com',
          action: tr('لماذا؟'),
          strong: false,
          iconColor: iconColor,
          iconSize: iconSize,
        ),
      ],
    );

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2700);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  /// يُبنى مرّةً ليُقرأ لونُ الحقل الحقيقيّ، ثمّ يُعاد البناءُ به.
  Future<Color?> fieldColor(WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
        _page(gap: Space.xl, iconColor: AppColors.muted, iconSize: 19)));
    await settle(tester);
    return _iconColor(tester, Icons.person_outline);
  }

  // ── السؤالُ الأوّل: الفراغُ تحت الغلاف ──────────────────────────────────
  for (final (name, gap) in const [
    ('today', Space.xl),
    ('a', 0.0),
    ('b', Space.sm),
  ]) {
    testWidgets('فراغٌ $gap تحت الغلاف', (tester) async {
      phone(tester);
      await tester.pumpWidget(
          _wrap(_page(gap: gap, iconColor: AppColors.muted, iconSize: 19)));
      await settle(tester);

      expect(find.text('بياناتي'), findsOneWidget,
          reason: 'البطاقةُ لم تُبنَ — فلا مقياسَ في اللقطة');
      expect(tester.takeException(), isNull);

      await _shoot(tester, '$out/gap-$name.png');
    });
  }

  // ── والثاني: لونُ أيقونتَي الجوال والبريد، والفراغُ صفرٌ كما طلب ────────
  testWidgets('اللونُ اليومَ — `muted` بقياس ١٩', (tester) async {
    phone(tester);
    final field = await fieldColor(tester);

    // **والفرقُ يُثبت لا يُدّعى**: لونُ أيقونة الحقل ليس `muted`.
    expect(field, isNot(AppColors.muted),
        reason: 'لا فرقَ أصلاً — فلا مقترحَ له');

    await tester.pumpWidget(
        _wrap(_page(gap: 0, iconColor: AppColors.muted, iconSize: 19)));
    await settle(tester);
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/icon-today.png');
  });

  testWidgets('(أ) لونُ الحقلين نفسُه بقياس ٢٠', (tester) async {
    phone(tester);
    final field = await fieldColor(tester);

    await tester
        .pumpWidget(_wrap(_page(gap: 0, iconColor: field, iconSize: 20)));
    await settle(tester);

    // **ويُتحقَّق من التساوي قبل اللقطة** — لا نقلَ بالعين.
    expect(_iconColor(tester, Icons.phone_outlined), field,
        reason: 'المرسومُ لم يساوِ المشحون');
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/icon-a.png');
  });

  testWidgets('(ب) لونُ الهويّة `accent` بقياس ٢٠', (tester) async {
    phone(tester);
    await tester.pumpWidget(
        _wrap(_page(gap: 0, iconColor: AppColors.accent, iconSize: 20)));
    await settle(tester);

    expect(tester.takeException(), isNull);
    await _shoot(tester, '$out/icon-b.png');
  });
}
