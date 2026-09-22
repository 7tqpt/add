// **مقترحٌ لا تنفيذ.** حوارُ «إيقاف تحسين استخدام البطّاريّة» في أوّل فتحة.
//
//   SHOTS=<مجلّد> flutter test tool/battery_prompt_proposal_test.dart
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «أبغى حلاً لهذه المشكلة، لأنّ العميل يحسب فيه شيءٌ غلط: هل تريد إيقاف
// تحسين استخدام البطّاريّة؟ ما أريدها تظهر».
//
// ── ومن أين تأتي ──────────────────────────────────────────────────────────
//
// `customer_shell.dart` و`provider_shell.dart` تناديان
// `askBatteryExemptionOnce()` بعد الدخول، فتفتح **حوارَ أندرويد نفسِه**
// مرّةً واحدةً في عمر التثبيت.
//
// **ولها سببٌ صحيح**: الجهازُ المقيِّد لا يوقظ التطبيقَ لرسالة FCM حتى
// تُفتح شاشتُه — فيتأخّر إشعارُ الحجز أو لا يصل. والإعفاءُ بيد صاحب الجهاز
// وحدَه، وأقصى ما تملكه شيفرةٌ أن تفتح له الحوار.
//
// **لكنّه يقع في أسوأ لحظة**: أوّلُ فتحةٍ للتطبيق، قبل أن يحجز شيئاً وقبل
// أن يفوته إشعار. فلا يُقرأ سبباً، ويُقرأ عطباً.
//
// ── ما هو مصوَّرٌ وما هو مرسوم ─────────────────────────────────────────────
//
// **الخليّةُ اليمنى مرسومةٌ ويُقال**: حوارُ «تحسين استخدام البطّاريّة»
// يرسمه **نظامُ أندرويد** لا التطبيق — فلا يُصوَّر من داخل `flutter test`
// ولا من داخل التطبيق أصلاً. ونصُّه هنا منقولٌ من لقطة صاحب المنصّة حرفاً.
//
// **والخليّةُ اليسرى مصوَّرةٌ من الشيفرة المدفوعة**: صفُّ «تقييد البطّاريّة»
// في شاشة الإعدادات — وهو الطريقُ الباقي إن ذهب الحوار. ويُعرض بجعل
// `batteryProbe` تردّ «مقيَّد»، وهي الوصلةُ نفسُها التي تقرأ الجهازَ الحقيقيّ.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/notification_tone.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account_extras.dart';

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
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const _label = TextStyle(fontFamily: brandFont, fontFamilyFallback: arabicFallback);

const _pw = 360.0;
const _ph = 620.0;
const _scale = 0.74;

Session _customer() => Session()
  ..userId = 'u1'
  ..email = 'cust@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

Widget _panel({
  required String caption,
  required String note,
  required Color captionColour,
  required Widget screen,
}) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _pw * _scale,
          height: _ph * _scale,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF3A3A3A), width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(width: _pw, height: _ph, child: screen),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: _pw * _scale,
          child: Text(caption,
              textAlign: TextAlign.center,
              style: _label.copyWith(
                  fontSize: 15, fontWeight: FontWeight.w700, color: captionColour)),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: _pw * _scale,
          child: Text(note,
              textAlign: TextAlign.center,
              style: _label.copyWith(fontSize: 11.5, color: AppColors.muted, height: 1.45)),
        ),
      ],
    );

/// **حوارُ أندرويد مرسوماً** — نصُّه من لقطة صاحب المنصّة حرفاً.
///
/// ولا يُصوَّر: يرسمه النظامُ فوق التطبيق، خارجَ أيّ شجرةٍ يبلغها الاختبار.
Widget _systemDialog() => Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.page),
        Container(color: Colors.black.withValues(alpha: 0.45)),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('هل تريد إيقاف تحسين استخدام البطارية؟',
                        style: _label.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF202124))),
                    const SizedBox(height: 12),
                    Text(
                      'سيكون بمقدور فرحتي التشغيل في الخلفية. لن يكون استخدامه '
                      'للبطارية مقيداً.',
                      style: _label.copyWith(
                          fontSize: 13, color: const Color(0xFF5F6368), height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('رفض',
                            style: _label.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A73E8))),
                        const SizedBox(width: 26),
                        Text('السماح',
                            style: _label.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A73E8))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

Widget _board(Widget settings) => Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حوارُ البطّاريّة في أوّل فتحة',
              style: _label.copyWith(
                  fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
          const SizedBox(height: 3),
          Text(
            'اليمنى مرسومةٌ — الحوارُ يرسمه نظامُ أندرويد لا التطبيق، فلا يُصوَّر، '
            'ونصُّه منقولٌ من لقطتك حرفاً. واليسرى مصوَّرةٌ من الشيفرة المدفوعة.',
            style: _label.copyWith(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panel(
                caption: 'اليوم — في أوّل فتحة',
                note: 'يُسأل مرّةً في عمر التثبيت،\nقبل أن يحجز شيئاً وقبل أن يفوته إشعار.',
                captionColour: AppColors.ink,
                screen: _systemDialog(),
              ),
              const SizedBox(width: 26),
              _panel(
                caption: 'والطريقُ الباقي إن ذهب',
                note: 'صفٌّ في «الإعدادات» لا يظهر إلّا لمن\nجهازُه مقيِّد، وضغطتُه تفتح الموضع.',
                captionColour: AppColors.accent,
                screen: settings,
              ),
            ],
          ),
        ],
      ),
    );

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
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(backgroundColor: AppColors.surface, body: child),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ حوار البطّاريّة', (tester) async {
    tester.view.physicalSize = const Size(760, 660);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // **الجهازُ مقيِّدٌ في هذه اللقطة** — وإلّا لم يُعرض الصفُّ أصلاً، وهو
    // المقصودُ تصويرُه. والوصلةُ هي نفسُها التي تقرأ الجهازَ الحقيقيّ.
    batteryProbe = () async => false;
    addTearDown(resetBatteryBridge);

    await tester.pumpWidget(_wrap(_board(
      SizedBox(width: _pw, height: _ph, child: SettingsScreen(session: _customer())),
    )));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // **ولا يُصدَّق أنّ اللوحَ رُسم: تُسأل الشجرة.**
    expect(find.byType(SettingsScreen), findsOneWidget, reason: 'الخليّةُ المصوَّرةُ غائبة');
    expect(find.byKey(const ValueKey('battery-restriction')), findsOneWidget,
        reason: 'صفُّ القيد غائبٌ — فلا طريقَ باقٍ يُصوَّر');
    expect(find.text('هل تريد إيقاف تحسين استخدام البطارية؟'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/battery-prompt.png');
  });
}
