// **مقترحٌ لا تنفيذ.** «افتح بالبصمة» في رأس «حسابي» — ثلاثةُ أشكالٍ في
// صورةٍ واحدة.
//
//   SHOTS=<مجلّد> flutter test tool/biometric_shortcut_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «اريد ايقون افتح بالبصمة تكون راس في حسابي».
//
// **وهي اليومَ ثلاثُ ضغطاتٍ بعيدة**: حسابي ← الإعدادات ← «الخصوصية والأمان»
// ← مفتاحُ البصمة (`account_extras.dart`، `SettingsScreen`). والأيقونةُ
// `Icons.fingerprint` موجودةٌ هناك بلونها — فالطلبُ نقلُ بابها إلى الرأس لا
// رسمُ أيقونةٍ جديدة.
//
// ── وما فيه حقيقيّ ────────────────────────────────────────────────────────
//
// `ProfileHeader` و`MenuSheet` و`MenuRow` هي ودجتاتُ الكِت نفسُها المشحونةُ
// في `account.dart`، بثيمة التطبيق (`buildTheme()`) وقياساتِها. **ولا صورةَ
// حقيقيّةً في القرص**: لا خادمَ في `flutter test` فيُرسم الحرفُ — وهو ما
// يُرى فعلاً لمن لا صورةَ له.
//
// ── وقيدٌ يخصّ الثلاثةَ جميعاً ──────────────────────────────────────────────
//
// **ولا بصمةَ بلا رمزٍ مضبوط** (`app_lock.dart`): البصمةُ بابٌ ثانٍ إلى
// القفل نفسِه لا بديلٌ عنه. فمن لا قفلَ له اليومَ يجب أن يُساق إلى ضبط
// الرمز أوّلاً، لا أن يُضغط مفتاحٌ فلا يقع شيء. وهذا يُحسم بعد اختيار الشكل.
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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  final image = await boundary.toImage(pixelRatio: 2.0);
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
        // **و`Scaffold` لا `ColoredBox` وحدَه:** `MenuRow` يبني `InkWell`،
        // وهو يطلب `Material` فوقه — وبلا ذلك تُرمى ثلاثُ استثناءاتٍ ولا
        // تُرسم الأبواب.
        home: Scaffold(
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

/// قرصُ الحرف — كما يُرسم لمن لا صورةَ له.
Widget _avatar() => Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.accentDeep,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'A',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w600,
          color: AppColors.accentInk,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

/// عنوانُ الخيار فوق رسمه.
Widget _caption(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

/// رأسٌ مختصرٌ بقياس الكِت — والشارةُ يسارَ الاسم كما في «حسابي».
Widget _head({Widget? titleTrailing}) => ProfileHeader(
      avatar: _avatar(),
      title: 'Ayman',
      subtitle: '',
      badge: tr('عريس'),
      badgeBesideTitle: true,
      titleTrailing: titleTrailing,
    );

/// أوّلُ صفَّين من أبواب «حسابي» — للسياق تحت كلّ خيار.
List<Widget> _menuTail() => [
      MenuRow(
        icon: Icons.person_outline_rounded,
        label: tr('الملف الشخصي'),
        onTap: () {},
      ),
      MenuRow(
        icon: Icons.receipt_long_outlined,
        label: tr('فواتيري'),
        onTap: () {},
        last: true,
      ),
    ];

void main() {
  setUpAll(_loadFonts);

  testWidgets('ثلاثةُ أشكالٍ في صورةٍ واحدة', (tester) async {
    tester.view.physicalSize = const Size(1180, 2560);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ColoredBox(
        color: AppColors.surface2,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── (أ) صفٌّ أوّلَ الأبواب يفتح إعداداتِ القفل ──────────────
            _caption('(أ) صفٌّ أوّلَ الأبواب — يفتح إعدادات القفل'),
            _head(),
            MenuSheet(
              children: [
                MenuRow(
                  icon: Icons.fingerprint,
                  label: tr('افتح بالبصمة'),
                  onTap: () {},
                ),
                ..._menuTail(),
              ],
            ),

            // ── (ب) أيقونةٌ في الرأس النبيذيّ نفسِه ─────────────────────
            _caption('(ب) أيقونةٌ في الرأس نفسِه — يسارَ الاسم'),
            // **ولونُ الأيقونة لون العلامة لا `accentInk`:** الاسمُ يقع على
            // الأبيض تحت الشريط النبيذيّ لا فوقه، و`accentInk` لونٌ للنبيذيّ
            // — فخرجت الأيقونةُ في أوّل رسمٍ غيرَ مرئيّةٍ بتاتاً.
            _head(
              titleTrailing: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint, size: 20, color: AppColors.accent),
              ),
            ),
            MenuSheet(children: _menuTail()),

            // ── (ج) صفٌّ أوّلَ الأبواب بمفتاحٍ فيه ──────────────────────
            _caption('(ج) صفٌّ أوّلَ الأبواب — بمفتاحٍ يُشغّل ويُطفئ فيه'),
            _head(),
            MenuSheet(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint, size: 22, color: AppColors.accent),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Text(
                          tr('افتح بالبصمة'),
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.ink,
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                      ),
                      Switch(value: true, onChanged: (_) {}),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.hairline),
                ..._menuTail(),
              ],
            ),
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.fingerprint), findsNWidgets(3),
        reason: 'الأشكالُ الثلاثةُ ليست كلُّها في الصورة');
    expect(find.byType(ProfileHeader), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/biometric-shortcut-options.png');
  });
}
